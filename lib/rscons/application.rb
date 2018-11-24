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

    # @return [String]
    #   Build directory (default "build").
    attr_accessor :build_dir

    # @return [String]
    #   Installation prefix (default "/usr/local").
    attr_accessor :prefix

    def initialize
      @n_threads = determine_n_threads
      @vars = VarSet.new
      @build_dir = "build"
      @prefix = "/usr/local"
      @default_environment = Environment.new
    end

    # Run the specified operation.
    #
    # @param operation [String]
    #   The operation to perform (e.g. "clean", "configure", "build", etc...)
    # @param script [Script]
    #   The script.
    #
    # @return [Integer]
    #   Process exit code (0 on success).
    def run(operation, script)
      @script = script
      case operation
      when "build"
        # TODO
        0
      when "clean"
        clean
      when "configure"
        configure
      else
        $stderr.puts "Unknown operation: #{operation}"
        1
      end
    end

    private

    # Remove all generated files.
    #
    # @return [void]
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
    # @return [void]
    def configure
      if project_name = @script.project_name
        Ansi.write($stdout, "Configuring ", :cyan, project_name, :reset, "...\n")
      else
        $stdout.puts "Configuring project..."
      end
      Ansi.write($stdout, "Setting build directory... ", :green, @build_dir, :reset, "\n")
      rv = 0
      co = ConfigureOp.new("#{@build_dir}/configure", @default_environment)
      begin
        @script.configure(co)
      rescue ConfigureOp::ConfigureFailure
        rv = 1
      end
      co.close
      cache = Cache.instance
      cache.set_configured(rv == 0)
      cache.set_default_environment_vars(@default_environment.to_h)
      cache.write
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
