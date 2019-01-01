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
    #   The number of threads to use for this Environment. If nil (the
    #   default), the global Rscons.application.n_threads default value will be
    #   used.
    attr_writer :n_threads

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
      @threaded_commands = Set.new
      @registered_build_dependencies = {}
      @side_effects = {}
      @job_set = JobSet.new(@registered_build_dependencies, @side_effects)
      @user_deps = {}
      @builders = {}
      @build_hooks = {pre: [], post: []}
      unless options[:exclude_builders]
        DEFAULT_BUILDERS.each do |builder_class_name|
          builder_class = Builders.const_get(builder_class_name)
          builder_class or raise "Could not find builder class #{builder_class_name}"
          add_builder(builder_class.new)
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
      @build_root = "#{Cache.instance.configuration_data["build_dir"]}/e.#{@id}"

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

    # Add a {Builder} object to the Environment.
    #
    # @overload add_builder(builder)
    #
    #   Add the given builder to the Environment.
    #
    #   @param builder [Builder] An instance of the builder to register.
    #
    # @overload add_builder(builder,&action)
    #
    #   Create a new {Builders::SimpleBuilder} instance and add it to the
    #   environment.
    #
    #   @since 1.8.0
    #
    #   @param builder [String,Symbol]
    #     The name of the builder to add.
    #
    #   @param action [Block]
    #     A block that will be called when the builder is executed to generate
    #     a target file. The provided block should have the same prototype as
    #     {Rscons::Builder#run}.
    #
    # @return [void]
    def add_builder(builder, &action)
      if not builder.is_a? Rscons::Builder
        builder = Rscons::Builders::SimpleBuilder.new(builder, &action)
      end
      @builders[builder.name] = builder
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
      cache = Cache.instance
      unless cache.configuration_data["configured"]
        raise "Project must be configured before processing an Environment"
      end
      failure = nil
      begin
        while @job_set.size > 0 or @threaded_commands.size > 0

          if failure
            @job_set.clear!
            job = nil
          else
            targets_still_building = @threaded_commands.map do |tc|
              tc.build_operation[:target]
            end
            job = @job_set.get_next_job_to_run(targets_still_building)
          end

          # TODO: have Cache determine when checksums may be invalid based on
          # file size and/or timestamp.
          cache.clear_checksum_cache!

          if job
            result = run_builder(job[:builder],
                                 job[:target],
                                 job[:sources],
                                 cache,
                                 job[:vars],
                                 allow_delayed_execution: true,
                                 setup_info: job[:setup_info])
            unless result
              failure = "Failed to build #{job[:target]}"
              Ansi.write($stderr, :red, failure, :reset, "\n")
              next
            end
          end

          completed_tcs = Set.new
          # First do a non-blocking wait to pick up any threads that have
          # completed since last time.
          while tc = wait_for_threaded_commands(nonblock: true)
            completed_tcs << tc
          end

          # If needed, do a blocking wait.
          if (@threaded_commands.size > 0) and
             ((completed_tcs.empty? and job.nil?) or (@threaded_commands.size >= n_threads))
            completed_tcs << wait_for_threaded_commands
          end

          # Process all completed {ThreadedCommand} objects.
          completed_tcs.each do |tc|
            result = finalize_builder(tc)
            if result
              @build_hooks[:post].each do |build_hook_block|
                build_hook_block.call(tc.build_operation)
              end
            else
              unless @echo == :command
                print_failed_command(tc.command)
              end
              failure = "Failed to build #{tc.build_operation[:target]}"
              Ansi.write($stderr, :red, failure, :reset, "\n")
              break
            end
          end

        end
      ensure
        cache.write
      end
      if failure
        raise BuildError.new(failure)
      end
    end

    # Clear all targets registered for the Environment.
    #
    # @return [void]
    def clear_targets
      @job_set.clear!
    end

    # Execute a builder command.
    #
    # @param short_desc [String] Message to print if the Environment's echo
    #   mode is set to :short
    # @param command [Array] The command to execute.
    # @param options [Hash] Optional options, possible keys:
    #   - :env - environment Hash to pass to Kernel#system.
    #   - :options - options Hash to pass to Kernel#system.
    #
    # @return [true,false,nil] Return value from Kernel.system().
    def execute(short_desc, command, options = {})
      print_builder_run_message(short_desc, command)
      env_args = options[:env] ? [options[:env]] : []
      options_args = options[:options] ? [options[:options]] : []
      system(*env_args, *Rscons.command_executer, *command, *options_args).tap do |result|
        unless result or @echo == :command
          print_failed_command(command)
        end
      end
    end

    # Define a build target.
    #
    # @param method [Symbol] Method name.
    # @param args [Array] Method arguments.
    #
    # @return [BuildTarget]
    #   The {BuildTarget} object registered, if the method called is a
    #   {Builder}.
    def method_missing(method, *args)
      if @builders.has_key?(method.to_s)
        target, sources, vars, *rest = args
        vars ||= {}
        unless vars.is_a?(Hash) or vars.is_a?(VarSet)
          raise "Unexpected construction variable set: #{vars.inspect}"
        end
        builder = @builders[method.to_s]
        target = expand_path(expand_varref(target))
        sources = Array(sources).map do |source|
          expand_path(expand_varref(source))
        end.flatten
        build_target = builder.create_build_target(env: self, target: target, sources: sources, vars: vars)
        add_target(build_target.to_s, builder, sources, vars, rest)
        build_target
      else
        super
      end
    end

    # Manually record a given target as depending on the specified files.
    #
    # @param target [String,BuildTarget] Target file.
    # @param user_deps [Array<String>] Dependency files.
    #
    # @return [void]
    def depends(target, *user_deps)
      target = expand_varref(target.to_s)
      user_deps = user_deps.map {|ud| expand_varref(ud)}
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
    # @param prerequisites [String, Array<String>]
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

    # Build a list of source files into files containing one of the suffixes
    # given by suffixes.
    #
    # This method is used internally by Rscons builders.
    #
    # @deprecated Use {#register_builds} instead.
    #
    # @param sources [Array<String>] List of source files to build.
    # @param suffixes [Array<String>]
    #   List of suffixes to try to convert source files into.
    # @param cache [Cache] The Cache.
    # @param vars [Hash] Extra variables to pass to the builder.
    #
    # @return [Array<String>] List of the converted file name(s).
    def build_sources(sources, suffixes, cache, vars)
      sources.map do |source|
        if source.end_with?(*suffixes)
          source
        else
          converted = nil
          suffixes.each do |suffix|
            converted_fname = get_build_fname(source, suffix)
            if builder = find_builder_for(converted_fname, source, [])
              converted = run_builder(builder, converted_fname, [source], cache, vars)
              return nil unless converted
              break
            end
          end
          converted or raise "Could not find a builder to handle #{source.inspect}."
        end
      end
    end

    # Find and register builders to build source files into files containing
    # one of the suffixes given by suffixes.
    #
    # This method is used internally by Rscons builders. It should be called
    # from the builder's #setup method.
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

    # Invoke a builder to build the given target based on the given sources.
    #
    # @param builder [Builder] The Builder to use.
    # @param target [String] The target output file.
    # @param sources [Array<String>] List of source files.
    # @param cache [Cache] The Cache.
    # @param vars [Hash] Extra variables to pass to the builder.
    # @param options [Hash]
    #   @since 1.10.0
    #   Options.
    # @option options [Boolean] :allow_delayed_execution
    #   @since 1.10.0
    #   Allow a threaded command to be scheduled but not yet completed before
    #   this method returns.
    # @option options [Object] :setup_info
    #   Arbitrary builder info returned by Builder#setup.
    #
    # @return [String,false] Return value from the {Builder}'s +run+ method.
    def run_builder(builder, target, sources, cache, vars, options = {})
      vars = @varset.merge(vars)
      build_operation = {
        builder: builder,
        target: target,
        sources: sources,
        cache: cache,
        env: self,
        vars: vars,
        setup_info: options[:setup_info]
      }
      call_build_hooks = lambda do |sec|
        @build_hooks[sec].each do |build_hook_block|
          build_hook_block.call(build_operation)
        end
      end

      # Invoke pre-build hooks.
      call_build_hooks[:pre]

      # Call the builder's #run method.
      if builder.method(:run).arity == 5
        rv = builder.run(*build_operation.values_at(:target, :sources, :cache, :env, :vars))
      else
        rv = builder.run(build_operation)
      end

      if rv.is_a?(ThreadedCommand)
        # Store the build operation so the post-build hooks can be called
        # with it when the threaded command completes.
        rv.build_operation = build_operation
        start_threaded_command(rv)
        unless options[:allow_delayed_execution]
          # Delayed command execution is not allowed, so we need to execute
          # the command and finalize the builder now.
          tc = wait_for_threaded_commands(which: [rv])
          rv = finalize_builder(tc)
          if rv
            call_build_hooks[:post]
          else
            unless @echo == :command
              print_failed_command(tc.command)
            end
          end
        end
      else
        call_build_hooks[:post] if rv
      end

      rv
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

    # Get the number of threads to use for parallelized builds in this
    # Environment.
    #
    # @return [Integer]
    #   Number of threads to use for parallelized builds in this Environment.
    def n_threads
      @n_threads || Rscons.application.n_threads
    end

    # Print the builder run message, depending on the Environment's echo mode.
    #
    # @param short_description [String]
    #   Builder short description, printed if the echo mode is :short.
    # @param command [Array<String>]
    #   Builder command, printed if the echo mode is :command.
    #
    # @return [void]
    def print_builder_run_message(short_description, command)
      case @echo
      when :command
        if command.is_a?(Array)
          message = command_to_s(command)
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

    # Print a failed command.
    #
    # @param command [Array<String>]
    #   Builder command.
    #
    # @return [void]
    def print_failed_command(command)
      Ansi.write($stdout, :red, "Failed command was: #{command_to_s(command)}", :reset, "\n")
    end

    private

    # Add a build target.
    #
    # @param target [String] Build target file name.
    # @param builder [Builder] The {Builder} to use to build the target.
    # @param sources [Array<String>] Source file name(s).
    # @param vars [Hash] Construction variable overrides.
    # @param args [Object] Deprecated; unused.
    #
    # @return [void]
    def add_target(target, builder, sources, vars, args)
      setup_info = builder.setup(
        target: target,
        sources: sources,
        env: self,
        vars: vars)
      @job_set.add_job(
        builder: builder,
        target: target,
        sources: sources,
        vars: vars,
        setup_info: setup_info)
    end

    # Start a threaded command in a new thread.
    #
    # @param tc [ThreadedCommand]
    #   The ThreadedCommand to start.
    #
    # @return [void]
    def start_threaded_command(tc)
      print_builder_run_message(tc.short_description, tc.command)

      env_args = tc.system_env ? [tc.system_env] : []
      options_args = tc.system_options ? [tc.system_options] : []
      system_args = [*env_args, *Rscons.command_executer, *tc.command, *options_args]

      tc.thread = Thread.new do
        system(*system_args)
      end
      @threaded_commands << tc
    end

    # Wait for threaded commands to complete.
    #
    # @param options [Hash]
    #   Options.
    # @option options [Set<ThreadedCommand>, Array<ThreadedCommand>] :which
    #   Which {ThreadedCommand} objects to wait for. If not specified, this
    #   method will wait for any.
    # @option options [Boolean] :nonblock
    #   Set to true to not block.
    #
    # @return [ThreadedCommand, nil]
    #   The {ThreadedCommand} object that is finished.
    def wait_for_threaded_commands(options = {})
      options[:which] ||= @threaded_commands
      threads = options[:which].map(&:thread)
      if finished_thread = find_finished_thread(threads, options[:nonblock])
        threaded_command = @threaded_commands.find do |tc|
          tc.thread == finished_thread
        end
        @threaded_commands.delete(threaded_command)
        threaded_command
      end
    end

    # Check if any of the requested threads are finished.
    #
    # @param threads [Array<Thread>]
    #   The threads to check.
    # @param nonblock [Boolean]
    #   Whether to be non-blocking. If true, nil will be returned if no thread
    #   is finished. If false, the method will wait until one of the threads
    #   is finished.
    #
    # @return [Thread, nil]
    #   The finished thread, if any.
    def find_finished_thread(threads, nonblock)
      if nonblock
        threads.find do |thread|
          !thread.alive?
        end
      else
        if threads.empty?
          raise "No threads to wait for"
        end
        ThreadsWait.new(*threads).next_wait
      end
    end

    # Return a string representation of a command.
    #
    # @param command [Array<String>]
    #   The command.
    #
    # @return [String]
    #   The string representation of the command.
    def command_to_s(command)
      command.map { |c| c =~ /\s/ ? "'#{c}'" : c }.join(' ')
    end

    # Call a builder's #finalize method after a ThreadedCommand terminates.
    #
    # @param tc [ThreadedCommand]
    #   The ThreadedCommand returned from the builder's #run method.
    #
    # @return [String, false]
    #   Result of Builder#finalize.
    def finalize_builder(tc)
      tc.build_operation[:builder].finalize(
        tc.build_operation.merge(
          command_status: tc.thread.value,
          tc: tc))
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
      @builders.values.find do |builder|
        features_met?(builder, features) and builder.produces?(target, source, self)
      end
    end

    # Determine if a builder meets the requested features.
    #
    # @param builder [Builder]
    #   The builder.
    # @param features [Array<String>]
    #   See {#register_builds}.
    #
    # @return [Boolean]
    #   Whether the builder meets the requested features.
    def features_met?(builder, features)
      builder_features = builder.features
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

    # Parse dependencies from a Makefile.
    #
    # This method is used internally by Rscons builders.
    #
    # @param mf_fname [String] File name of the Makefile to read.
    #
    # @return [Array<String>] Paths of dependency files.
    def self.parse_makefile_deps(mf_fname)
      deps = []
      buildup = ''
      File.read(mf_fname).each_line do |line|
        if line =~ /^(.*)\\\s*$/
          buildup += ' ' + $1
        else
          buildup += ' ' + line
          if buildup =~ /^.*: (.*)$/
            mf_deps = $1
            deps += mf_deps.split(' ').map(&:strip)
          end
          buildup = ''
        end
      end
      deps
    end

  end

  Environment.class_init
end
