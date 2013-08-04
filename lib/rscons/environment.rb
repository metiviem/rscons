require 'set'
require 'fileutils'

module Rscons
  # The Environment class is the main programmatic interface to RScons. It
  # contains a collection of construction variables, options, builders, and
  # rules for building targets.
  class Environment
    # [Array] of {Builder} objects.
    attr_reader :builders

    # Create an Environment object.
    # @param variables [Hash]
    #   The variables hash can contain both construction variables, which are
    #   uppercase strings (such as "CC" or "LDFLAGS"), and RScons options,
    #   which are lowercase symbols (such as :echo).
    def initialize(variables = {})
      @varset = VarSet.new(variables)
      @targets = {}
      @builders = {}
      @build_dirs = {}
      @varset[:exclude_builders] ||= []
      unless @varset[:exclude_builders] == :all
        exclude_builders = Set.new(@varset[:exclude_builders] || [])
        DEFAULT_BUILDERS.each do |builder_class|
          unless exclude_builders.include?(builder_class.short_name)
            add_builder(builder_class.new)
          end
        end
      end
      (@varset[:builders] || []).each do |builder|
        add_builder(builder)
      end
      @varset[:echo] ||= :command

      if block_given?
        yield self
        self.process
      end
    end

    # Make a copy of the Environment object.
    # The cloned environment will contain a copy of all environment options,
    # construction variables, builders, and build directories. It will not
    # contain a copy of the targets.
    def clone(variables = {})
      env = Environment.new()
      @builders.each do |builder_name, builder|
        env.add_builder(builder)
      end
      @build_dirs.each do |src_dir, obj_dir|
        env.build_dir(src_dir, obj_dir)
      end
      env.append(@varset)
      env.append(variables)

      if block_given?
        yield env
        env.process
      end
      env
    end

    # Add a {Builder} object to the Environment.
    def add_builder(builder)
      @builders[builder.class.short_name] = builder
      var_defs = builder.default_variables(self)
      if var_defs
        var_defs.each_pair do |var, val|
          @varset[var] ||= val
        end
      end
    end

    # Specify a build directory for this Environment.
    # Source files from src_dir will produce object files under obj_dir.
    def build_dir(src_dir, obj_dir)
      @build_dirs[src_dir.gsub('\\', '/')] = obj_dir.gsub('\\', '/')
    end

    # Return the file name to be built from source_fname with suffix suffix.
    # This method takes into account the Environment's build directories.
    # It also creates any parent directories needed to be able to open and
    # write to the output file.
    def get_build_fname(source_fname, suffix)
      build_fname = source_fname.set_suffix(suffix).gsub('\\', '/')
      @build_dirs.each do |src_dir, obj_dir|
        build_fname.sub!(/^#{src_dir}\//, "#{obj_dir}/")
      end
      FileUtils.mkdir_p(File.dirname(build_fname))
      build_fname
    end

    # Access a construction variable or environment option.
    # @see VarSet#[]
    def [](*args)
      @varset.send(:[], *args)
    end

    # Set a construction variable or environment option.
    # @see VarSet#[]=
    def []=(*args)
      @varset.send(:[]=, *args)
    end

    # Add a set of construction variables or environment options.
    # @see VarSet#append
    def append(*args)
      @varset.send(:append, *args)
    end

    # Return a list of target file names
    def targets
      @targets.keys
    end

    # Return a list of sources needed to build target target.
    def target_sources(target)
      @targets[target][:source] rescue nil
    end

    # Build all target specified in the Environment.
    # When a block is passed to Environment.new, this method is automatically
    # called after the block returns.
    def process
      cache = Cache.new
      targets_processed = Set.new
      process_target = proc do |target|
        if @targets[target][:source].map do |src|
          targets_processed.include?(src) or not @targets.include?(src) or process_target.call(src)
        end.all?
          @targets[target][:builder].run(target,
                                         @targets[target][:source],
                                         cache,
                                         self,
                                         *@targets[target][:args])
        else
          false
        end
      end
      @targets.each do |target, info|
        next if targets_processed.include?(target)
        unless process_target.call(target)
          $stderr.puts "Error: failed to build #{target}"
          break
        end
      end
      cache.write
    end

    # Build a command line from the given template, resolving references to
    # variables using the Environment's construction variables and any extra
    # variables specified.
    # @param command_template [Array] template for the command with variable
    #   references
    # @param extra_vars [Hash, VarSet] extra variables to use in addition to
    #   (or replace) the Environment's construction variables when building
    #   the command
    def build_command(command_template, extra_vars)
      @varset.merge(extra_vars).expand_varref(command_template)
    end

    # Execute a builder command
    # @param short_desc [String] Message to print if the Environment's :echo
    #   mode is set to :short
    # @param command [Array] The command to execute.
    # @param options [Hash] Optional options to pass to {Kernel#system}.
    def execute(short_desc, command, options = {})
      print_command = proc do
        puts command.map { |c| c =~ /\s/ ? "'#{c}'" : c }.join(' ')
      end
      if @varset[:echo] == :command
        print_command.call
      elsif @varset[:echo] == :short
        puts short_desc
      end
      system(*command, options).tap do |result|
        unless result or @varset[:echo] == :command
          $stdout.write "Failed command was: "
          print_command.call
        end
      end
    end

    alias_method :orig_method_missing, :method_missing
    def method_missing(method, *args)
      if @builders.has_key?(method.to_s)
        target, source, *rest = args
        source = [source] unless source.is_a?(Array)
        @targets[target] = {
          builder: @builders[method.to_s],
          source: source,
          args: rest,
        }
      else
        orig_method_missing(method, *args)
      end
    end

    # Parse dependencies for a given target from a Makefile.
    # This method is used internally by RScons builders.
    # @param mf_fname [String] File name of the Makefile to read.
    # @param target [String] Name of the target to gather dependencies for.
    def parse_makefile_deps(mf_fname, target)
      deps = []
      buildup = ''
      File.read(mf_fname).each_line do |line|
        if line =~ /^(.*)\\\s*$/
          buildup += ' ' + $1
        else
          if line =~ /^(.*): (.*)$/
            target, tdeps = $1.strip, $2
            if target == target
              deps += tdeps.split(' ').map(&:strip)
            end
          end
          buildup = ''
        end
      end
      deps
    end
  end
end
