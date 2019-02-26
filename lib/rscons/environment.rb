require "fileutils"
require "set"
require "shellwords"
require "thwait"

module Rscons
  # The Environment class is the main programmatic interface to Rscons. It
  # contains a collection of construction variables, options, builders, and
  # rules for building targets.
  class Environment < BasicEnvironment

    class << self

      # @return [Array<Environment>]
      #   All Environments.
      attr_reader :environments

      # Initialize class instance variables.
      def class_init
        @environments = []
      end

      # Get an ID for a new Environment. This is a monotonically increasing
      # integer.
      #
      # @return [Integer]
      #   Environment ID.
      def get_id
        @id ||= 0
        @id += 1
        @id
      end

      # Register an Environment.
      def register(env)
        @environments ||= []
        @environments << env
      end
    end

    # @return [Hash] Set of !{"builder_name" => builder_object} pairs.
    attr_reader :builders

    # @return [Symbol] :command, :short, or :off
    attr_accessor :echo

    # @return [String] The build root.
    attr_reader :build_root

    # @return [Integer]
    #   The number of threads to use for this Environment. Defaults to the
    #   global Rscons.application.n_threads value.
    attr_accessor :n_threads

    # Create an Environment object.
    #
    # @param options [Hash]
    # @option options [Symbol] :echo
    #   :command, :short, or :off (default :short)
    # @option options [Boolean] :exclude_builders
    #   Whether to omit adding default builders (default false)
    #
    # If a block is given, the Environment object is yielded to the block and
    # when the block returns, the {#process} method is automatically called.
    def initialize(options = {})
      super(options)
      @id = self.class.get_id
      self.class.register(self)
      # Hash of Thread object => {Command} or {Builder}.
      @threads = {}
      @registered_build_dependencies = {}
      @side_effects = {}
      @builder_set = BuilderSet.new(@registered_build_dependencies, @side_effects)
      @user_deps = {}
      # Hash of builder name (String) => builder class (Class).
      @builders = {}
      @build_hooks = {pre: [], post: []}
      unless options[:exclude_builders]
        DEFAULT_BUILDERS.each do |builder_class_name|
          builder_class = Builders.const_get(builder_class_name)
          builder_class or raise "Could not find builder class #{builder_class_name}"
          add_builder(builder_class)
        end
      end
      @echo =
        if options[:echo]
          options[:echo]
        elsif Rscons.application.verbose
          :command
        else
          :short
        end
      @build_root = "#{Cache.instance["configuration_data"]["build_dir"]}/e.#{@id}"
      @n_threads = Rscons.application.n_threads

      if block_given?
        yield self
      end
    end

    # Make a copy of the Environment object.
    #
    # By default, a cloned environment will contain a copy of all environment
    # options, construction variables, and builders, but not a copy of the
    # targets, build hooks, build directories, or the build root.
    #
    # Exactly which items are cloned are controllable via the optional :clone
    # parameter, which can be :none, :all, or a set or array of any of the
    # following:
    # - :variables to clone construction variables (on by default)
    # - :builders to clone the builders (on by default)
    # - :build_hooks to clone the build hooks (on by default)
    #
    # If a block is given, the Environment object is yielded to the block and
    # when the block returns, the {#process} method is automatically called.
    #
    # Any options that #initialize receives can also be specified here.
    #
    # @return [Environment] The newly created {Environment} object.
    def clone(options = {})
      clone = options[:clone] || :all
      clone = Set[:variables, :builders, :build_hooks] if clone == :all
      clone = Set[] if clone == :none
      clone = Set.new(clone) if clone.is_a?(Array)
      clone.delete(:builders) if options[:exclude_builders]
      env = self.class.new(
        echo: options[:echo] || @echo,
        exclude_builders: true)
      if clone.include?(:builders)
        @builders.each do |builder_name, builder|
          env.add_builder(builder)
        end
      end
      env.append(@varset) if clone.include?(:variables)
      if clone.include?(:build_hooks)
        @build_hooks[:pre].each do |build_hook_block|
          env.add_build_hook(&build_hook_block)
        end
        @build_hooks[:post].each do |build_hook_block|
          env.add_post_build_hook(&build_hook_block)
        end
      end
      env.instance_variable_set(:@n_threads, @n_threads)

      if block_given?
        yield env
      end
      env
    end

    # Add a {Builder} to the Environment.
    #
    # @overload add_builder(builder_class)
    #
    #   Add the given builder to the Environment.
    #
    #   @param builder_class [Class] A builder class to register.
    #
    # @overload add_builder(name,&action)
    #
    #   Create a new {Builders::SimpleBuilder} instance and add it to the
    #   environment.
    #
    #   @since 1.8.0
    #
    #   @param name [String,Symbol]
    #     The name of the builder to add.
    #
    #   @param action [Block]
    #     A block that will be called when the builder is executed to generate
    #     a target file. The provided block should have the same prototype as
    #     {Rscons::Builder#run}.
    #
    # @return [void]
    def add_builder(builder_class, &action)
      if builder_class.is_a?(String) or builder_class.is_a?(Symbol)
        name = builder_class.to_s
        builder_class = BuilderBuilder.new(Rscons::Builders::SimpleBuilder, name, &action)
      else
        name = builder_class.name
      end
      @builders[name] = builder_class
    end

    # Add a build hook to the Environment.
    #
    # Build hooks are Ruby blocks which are invoked immediately before a
    # build operation takes place. Build hooks have an opportunity to modify
    # the construction variables in use for the build operation based on the
    # builder in use, target file name, or sources. Build hooks can also
    # register new build targets.
    #
    # @yield [build_op]
    #   Invoke the given block with the current build operation.
    # @yieldparam build_op [Hash]
    #   Hash with keys:
    #   - :builder - The builder object in use.
    #   - :target - Target file name.
    #   - :sources - List of source file(s).
    #   - :vars - Set of construction variable values in use.
    #   - :env - The Environment invoking the builder.
    #
    # @return [void]
    def add_build_hook(&block)
      @build_hooks[:pre] << block
    end

    # Add a post build hook to the Environment.
    #
    # Post-build hooks are Ruby blocks which are invoked immediately after a
    # build operation takes place. Post-build hooks are only invoked if the
    # build operation succeeded. Post-build hooks can register new build
    # targets.
    #
    # @since 1.7.0
    #
    # @yield [build_op]
    #   Invoke the given block with the current build operation.
    # @yieldparam build_op [Hash]
    #   Hash with keys:
    #   - :builder - The builder object in use.
    #   - :target - Target file name.
    #   - :sources - List of source file(s).
    #   - :vars - Set of construction variable values in use.
    #   - :env - The Environment invoking the builder.
    #
    # @return [void]
    def add_post_build_hook(&block)
      @build_hooks[:post] << block
    end

    # Return the file name to be built from +source_fname+ with suffix
    # +suffix+.
    #
    # This method takes into account the Environment's build directories.
    #
    # @param source_fname [String]
    #   Source file name.
    # @param suffix [String]
    #   Suffix, including "." if desired.
    # @param options [Hash]
    #   Extra options.
    # @option options [Array<String>] :features
    #   Builder features to be used for this build. See {#register_builds}.
    #
    # @return [String]
    #   The file name to be built from +source_fname+ with suffix +suffix+.
    def get_build_fname(source_fname, suffix, options = {})
      options[:features] ||= []
      extra_path = options[:features].include?("shared") ? "/_shared" : ""
      "#{@build_root}#{extra_path}/#{Util.make_relative_path(Rscons.set_suffix(source_fname, suffix))}".gsub("\\", "/")
    end

    # Build all build targets specified in the Environment.
    #
    # When a block is passed to Environment.new, this method is automatically
    # called after the block returns.
    #
    # @return [void]
    def process
      unless Cache.instance["configuration_data"]["configured"]
        raise "Project must be configured before processing an Environment"
      end
      @process_failures = []
      @process_blocking_wait = false
      @process_commands_waiting_to_run = []
      @process_builder_waits = {}
      @process_builders_to_run = []
      begin
        while @builder_set.size > 0 or @threads.size > 0 or @process_commands_waiting_to_run.size > 0
          process_step
          unless @process_failures.empty?
            # On a build failure, do not start any more builders or commands,
            # but let the threads that have already been started complete.
            @builder_set.clear
            @process_commands_waiting_to_run.clear
          end
        end
      ensure
        Cache.instance.write
      end
      unless @process_failures.empty?
        msg = @process_failures.join("\n")
        if Cache.instance["failed_commands"].size > 0
          msg += "\nRun `#{$0} -F` to see the failed command(s)."
        end
        raise BuildError.new(msg)
      end
    end

    # Clear all targets registered for the Environment.
    #
    # @return [void]
    def clear_targets
      @builder_set.clear
    end

    # Define a build target.
    #
    # @param method [Symbol] Method name.
    # @param args [Array] Method arguments.
    #
    # @return [Builder]
    #   The {Builder} object registered, if the method called is the name of a
    #   registered {Builder}.
    def method_missing(method, *args)
      if @builders.has_key?(method.to_s)
        target, sources, vars, *rest = args
        vars ||= {}
        unless vars.is_a?(Hash) or vars.is_a?(VarSet)
          raise "Unexpected construction variable set: #{vars.inspect}"
        end
        target = expand_path(expand_varref(target))
        sources = Array(sources).map do |source|
          expand_path(expand_varref(source))
        end.flatten
        builder = @builders[method.to_s].new(
          target: target,
          sources: sources,
          cache: Cache.instance,
          env: self,
          vars: vars)
        @builder_set << builder
        builder
      else
        super
      end
    end

    # Manually record a given target as depending on the specified files.
    #
    # @param target [String, Builder] Target file.
    # @param user_deps [Array<String, Builder>] Dependency files.
    #
    # @return [void]
    def depends(target, *user_deps)
      if target.is_a?(Builder)
        target = target.target
      end
      target = expand_varref(target.to_s)
      user_deps = user_deps.map do |ud|
        if ud.is_a?(Builder)
          ud = ud.target
        end
        expand_varref(ud)
      end
      @user_deps[target] ||= []
      @user_deps[target] = (@user_deps[target] + user_deps).uniq
      build_after(target, user_deps)
    end

    # Manually record the given target(s) as needing to be built after the
    # given prerequisite(s).
    #
    # For example, consider a builder registered to generate gen.c which also
    # generates gen.h as a side-effect. If program.c includes gen.h, then it
    # should not be compiled before gen.h has been generated. When using
    # multiple threads to build, Rscons may attempt to compile program.c before
    # gen.h has been generated because it does not know that gen.h will be
    # generated along with gen.c. One way to prevent that situation would be
    # to first process the Environment with just the code-generation builders
    # in place and then register the compilation builders. Another way is to
    # use this method to record that a certain target should not be built until
    # another has completed. For example, for the situation previously
    # described:
    #   env.build_after("program.o", "gen.c")
    #
    # @since 1.10.0
    #
    # @param targets [String, Array<String>]
    #   Target files to wait to build until the prerequisites are finished
    #   building.
    # @param prerequisites [String, Builder, Array<String, Builder>]
    #   Files that must be built before building the specified targets.
    #
    # @return [void]
    def build_after(targets, prerequisites)
      targets = Array(targets)
      prerequisites = Array(prerequisites)
      targets.each do |target|
        target = expand_path(expand_varref(target))
        @registered_build_dependencies[target] ||= Set.new
        prerequisites.each do |prerequisite|
          if prerequisite.is_a?(Builder)
            prerequisite = prerequisite.target
          end
          prerequisite = expand_path(expand_varref(prerequisite))
          @registered_build_dependencies[target] << prerequisite
        end
      end
    end

    # Manually record the given side effect file(s) as being produced when the
    # named target is produced.
    #
    # @since 1.13.0
    #
    # @param target [String]
    #   Target of a build operation.
    # @param side_effects [Array<String>]
    #   File(s) produced when the target file is produced.
    #
    # @return [void]
    def produces(target, *side_effects)
      target = expand_path(expand_varref(target))
      side_effects = Array(side_effects).map do |side_effect|
        expand_path(expand_varref(side_effect))
      end.flatten
      @side_effects[target] ||= []
      @side_effects[target] += side_effects
    end

    # Return the list of user dependencies for a given target.
    #
    # @param target [String] Target file name.
    #
    # @return [Array<String>,nil]
    #   List of user-specified dependencies for the target, or nil if none were
    #   specified.
    def get_user_deps(target)
      @user_deps[target]
    end

    # Find and register builders to build source files into files containing
    # one of the suffixes given by suffixes.
    #
    # This method is used internally by Rscons builders. It can be called
    # from the builder's #initialize method.
    #
    # @since 1.10.0
    #
    # @param target [String]
    #   The target that depends on these builds.
    # @param sources [Array<String>]
    #   List of source file(s) to build.
    # @param suffixes [Array<String>]
    #   List of suffixes to try to convert source files into.
    # @param vars [Hash]
    #   Extra variables to pass to the builders.
    # @param options [Hash]
    #   Extra options.
    # @option options [Array<String>] :features
    #   Set of features the builder must provide. Each feature can be proceeded
    #   by a "-" character to indicate that the builder must /not/ provide the
    #   given feature.
    #   * shared - builder builds a shared object/library
    #
    # @return [Array<String>]
    #   List of the output file name(s).
    def register_builds(target, sources, suffixes, vars, options = {})
      options[:features] ||= []
      @registered_build_dependencies[target] ||= Set.new
      sources.map do |source|
        if source.end_with?(*suffixes)
          source
        else
          output_fname = nil
          suffixes.each do |suffix|
            attempt_output_fname = get_build_fname(source, suffix, features: options[:features])
            if builder = find_builder_for(attempt_output_fname, source, options[:features])
              output_fname = attempt_output_fname
              self.__send__(builder.name, output_fname, source, vars)
              @registered_build_dependencies[target] << output_fname
              break
            end
          end
          output_fname or raise "Could not find a builder for #{source.inspect}."
        end
      end
    end

    # Expand a path to be relative to the Environment's build root.
    #
    # Paths beginning with "^/" are expanded by replacing "^" with the
    # Environment's build root.
    #
    # @param path [String, Array<String>]
    #   The path(s) to expand.
    #
    # @return [String, Array<String>]
    #   The expanded path(s).
    def expand_path(path)
      if Rscons.phony_target?(path)
        path
      elsif path.is_a?(Array)
        path.map do |path|
          expand_path(path)
        end
      else
        path.sub(%r{^\^(?=[\\/])}, @build_root).gsub("\\", "/")
      end
    end

    # Execute a command using the system shell.
    #
    # The shell is automatically determined but can be overridden by the SHELL
    # construction variable. If the SHELL construction variable is specified,
    # the flag to pass to the shell is automatically dtermined but can be
    # overridden by the SHELLFLAG construction variable.
    #
    # @param command [String] Command to execute.
    #
    # @return [String] The command's standard output.
    def shell(command)
      shell_cmd =
        if self["SHELL"]
          flag = self["SHELLFLAG"] || (self["SHELL"] == "cmd" ? "/c" : "-c")
          [self["SHELL"], flag]
        else
          Rscons.get_system_shell
        end
      IO.popen([*shell_cmd, command]) do |io|
        io.read
      end
    end

    # Print the builder run message, depending on the Environment's echo mode.
    #
    # @param builder [Builder]
    #   The {Builder} that is executing.
    # @param short_description [String]
    #   Builder short description, printed if the echo mode is :short, or if
    #   there is no command.
    # @param command [Array<String>]
    #   Builder command, printed if the echo mode is :command.
    #
    # @return [void]
    def print_builder_run_message(builder, short_description, command)
      case @echo
      when :command
        if command.is_a?(Array)
          message = Util.command_to_s(command)
        elsif command.is_a?(String)
          message = command
        elsif short_description.is_a?(String)
          message = short_description
        end
      when :short
        message = short_description if short_description
      end
      Ansi.write($stdout, :cyan, message, :reset, "\n") if message
    end

    private

    # Run a builder and process its return value.
    #
    # @param builder [Builder]
    #   The builder.
    #
    # @return [void]
    def run_builder(builder)
      # TODO: have Cache determine when checksums may be invalid based on
      # file size and/or timestamp.
      Cache.instance.clear_checksum_cache!
      case result = builder.run({})
      when Array
        result.each do |waititem|
          @process_builder_waits[builder] ||= Set.new
          @process_builder_waits[builder] << waititem
          case waititem
          when Thread
            @threads[waititem] = builder
          when Command
            @process_commands_waiting_to_run << waititem
          when Builder
            # No action needed.
          else
            raise "Unrecognized #{builder.name} builder return item: #{waititem.inspect}"
          end
        end
      when false
        @process_failures << "Failed to build #{builder.target}."
      when true
        # Register side-effect files as build targets so that a Cache
        # clean operation will remove them.
        (@side_effects[builder.target] || []).each do |side_effect_file|
          Cache.instance.register_build(side_effect_file, nil, [], self)
        end
        @build_hooks[:post].each do |build_hook_block|
          build_hook_block.call(builder)
        end
        process_remove_wait(builder)
      else
        raise "Unrecognized #{builder.name} builder return value: #{result.inspect}"
      end
    end

    # Remove an item that a builder may have been waiting on.
    #
    # @param waititem [Object]
    #   Item that a builder may be waiting on.
    #
    # @return [void]
    def process_remove_wait(waititem)
      @process_builder_waits.to_a.each do |builder, waits|
        if waits.include?(waititem)
          waits.delete(waititem)
        end
        if waits.empty?
          @process_builder_waits.delete(builder)
          @process_builders_to_run << builder
        end
      end
    end

    # Broken out from {#process} to perform a single operation.
    #
    # @return [void]
    def process_step
      # Check if a thread has completed since last time.
      thread = find_finished_thread(true)

      # Check if we need to do a blocking wait for a thread to complete.
      if thread.nil? and (@threads.size >= n_threads or @process_blocking_wait)
        thread = find_finished_thread(false)
        @process_blocking_wait = false
      end

      if thread
        # We found a completed thread.
        process_remove_wait(thread)
        builder = builder_for_thread(thread)
        completed_command = @threads[thread]
        @threads.delete(thread)
        if completed_command.is_a?(Command)
          process_remove_wait(completed_command)
          completed_command.status = thread.value
          unless completed_command.status
            Cache.instance["failed_commands"] << completed_command.command
            @process_failures << "Failed to build #{builder.target}."
            return
          end
        end
      end

      if @threads.size < n_threads and @process_commands_waiting_to_run.size > 0
        # There is a command waiting to run and a thread free to run it.
        command = @process_commands_waiting_to_run.slice!(0)
        @threads[command.run] = command
        return
      end

      unless @process_builders_to_run.empty?
        # There is a builder waiting to run that was unblocked by its wait
        # items completing.
        return run_builder(@process_builders_to_run.slice!(0))
      end

      # If no builder was found to run yet and there are threads available, try
      # to get a runnable builder from the builder set.
      targets_still_building = @threads.reduce([]) do |result, (thread, obj)|
        result << builder_for_thread(thread).target
      end
      builder = @builder_set.get_next_builder_to_run(targets_still_building)

      if builder
        builder.vars = @varset.merge(builder.vars)
        @build_hooks[:pre].each do |build_hook_block|
          build_hook_block.call(builder)
        end
        return run_builder(builder)
      end

      if @threads.size > 0
        # A runnable builder was not found but there is a thread running,
        # so next time do a blocking wait for a thread to complete.
        @process_blocking_wait = true
      end
    end

    # Find a finished thread.
    #
    # @param nonblock [Boolean]
    #   Whether to be non-blocking. If true, nil will be returned if no thread
    #   is finished. If false, the method will wait until one of the threads
    #   is finished.
    #
    # @return [Thread, nil]
    #   The finished thread, if any.
    def find_finished_thread(nonblock)
      if nonblock
        @threads.keys.find do |thread|
          !thread.alive?
        end
      else
        if @threads.empty?
          raise "No threads to wait for"
        end
        ThreadsWait.new(*@threads.keys).next_wait
      end
    end

    # Get the {Builder} waiting on the given Thread.
    #
    # @param thread [Thread]
    #   The thread.
    #
    # @return [Builder]
    #   The {Builder} waiting on the given thread.
    def builder_for_thread(thread)
      if @threads[thread].is_a?(Command)
        @threads[thread].builder
      else
        @threads[thread]
      end
    end

    # Find a builder that meets the requested features and produces a target
    # of the requested name.
    #
    # @param target [String]
    #   Target file name.
    # @param source [String]
    #   Source file name.
    # @param features [Array<String>]
    #   See {#register_builds}.
    #
    # @return [Builder, nil]
    #   The builder found, if any.
    def find_builder_for(target, source, features)
      @builders.values.find do |builder_class|
        features_met?(builder_class, features) and builder_class.produces?(target, source, self)
      end
    end

    # Determine if a builder meets the requested features.
    #
    # @param builder_class [Class]
    #   The builder.
    # @param features [Array<String>]
    #   See {#register_builds}.
    #
    # @return [Boolean]
    #   Whether the builder meets the requested features.
    def features_met?(builder_class, features)
      builder_features = builder_class.features
      features.all? do |feature|
        want_feature = true
        if feature =~ /^-(.*)$/
          want_feature = false
          feature = $1
        end
        builder_has_feature = builder_features.include?(feature)
        want_feature ? builder_has_feature : !builder_has_feature
      end
    end

  end

  Environment.class_init
end
