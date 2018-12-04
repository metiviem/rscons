module Rscons

  # Functionality for an instance of the rscons application invocation.
  class Application

    # @return [Boolean]
    #   Whether to output ANSI color escape sequences.
    attr_accessor :do_ansi_color

    # @return [Integer]
    #   The number of threads to use when scheduling subprocesses.
    attr_accessor :n_threads

    # @return [VarSet]
    #   Access any variables set on the rscons command-line.
    attr_reader :vars

    def initialize
      @n_threads = determine_n_threads
      @vars = VarSet.new
    end

    # Run the specified operation.
    #
    # @param operation [String]
    #   The operation to perform (e.g. "clean", "configure", "build", etc...)
    # @param script [Script]
    #   The script.
    # @param operation_options [Hash]
    #   Option values from the CLI for the operation.
    #
    # @return [Integer]
    #   Process exit code (0 on success).
    def run(operation, script, operation_options)
      @script = script
      case operation
      when "build"
        unless Cache.instance.configuration_data["configured"]
          if @script.autoconf
            rv = configure(operation_options)
            if rv != 0
              return rv
            end
          else
            $stderr.puts "Project must be configured first, and autoconf is disabled"
            return 1
          end
        end
        build(operation_options)
      when "clean"
        clean
      when "configure"
        configure(operation_options)
      else
        $stderr.puts "Unknown operation: #{operation}"
        1
      end
    end

    private

    # Build the project.
    #
    # @param options [Hash]
    #   Options.
    #
    # @return [Integer]
    #   Exit code.
    def build(options)
      begin
        Environment.environments.each do |env|
          env.process
        end
        0
      rescue BuildError => be
        $stderr.puts be
        1
      end
    end

    # Remove all generated files.
    #
    # @return [Integer]
    #   Exit code.
    def clean
      cache = Cache.instance
      # remove all built files
      cache.targets.each do |target|
        FileUtils.rm_f(target)
      end
      # remove all created directories if they are empty
      cache.directories.sort {|a, b| b.size <=> a.size}.each do |directory|
        next unless File.directory?(directory)
        if (Dir.entries(directory) - ['.', '..']).empty?
          Dir.rmdir(directory) rescue nil
        end
      end
      cache.clear
      0
    end

    # Configure the project.
    #
    # @param options [Hash]
    #   Options.
    #
    # @return [Integer]
    #   Exit code.
    def configure(options)
      # Default options.
      options[:build_dir] ||= "build"
      options[:prefix] ||= "/usr/local"
      cache = Cache.instance
      cache.configuration_data = {}
      if project_name = @script.project_name
        Ansi.write($stdout, "Configuring ", :cyan, project_name, :reset, "...\n")
      else
        $stdout.puts "Configuring project..."
      end
      Ansi.write($stdout, "Setting build directory... ", :green, options[:build_dir], :reset, "\n")
      Ansi.write($stdout, "Setting prefix... ", :green, options[:prefix], :reset, "\n")
      rv = 0
      co = ConfigureOp.new("#{options[:build_dir]}/configure")
      begin
        @script.configure(co)
      rescue ConfigureOp::ConfigureFailure
        rv = 1
      end
      co.close
      cache.configuration_data["build_dir"] = options[:build_dir]
      cache.configuration_data["prefix"] = options[:prefix]
      cache.configuration_data["configured"] = rv == 0
      cache.write!
      rv
    end

    # Determine the number of threads to use by default.
    #
    # @return [Integer]
    #   The number of threads to use by default.
    def determine_n_threads
      # If the user specifies the number of threads in the environment, then
      # respect that.
      if ENV["RSCONS_NTHREADS"] =~ /^(\d+)$/
        return $1.to_i
      end

      # Otherwise try to figure out how many threads are available on the
      # host hardware.
      begin
        case RbConfig::CONFIG["host_os"]
        when /linux/
          return File.read("/proc/cpuinfo").scan(/^processor\s*:/).size
        when /mswin|mingw/
          if `wmic cpu get NumberOfLogicalProcessors /value` =~ /NumberOfLogicalProcessors=(\d+)/
            return $1.to_i
          end
        when /darwin/
          if `sysctl -n hw.ncpu` =~ /(\d+)/
            return $1.to_i
          end
        end
      rescue
      end

      # If we can't figure it out, default to 1.
      1
    end

  end

end
