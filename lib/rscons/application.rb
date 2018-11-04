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
      when "clean"
        clean
      when "configure"
        configure
      end
      0
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
    end

    # Configure the project.
    #
    # @return [void]
    def configure
      if ccc = @script.check_c_compiler
        check_c_compiler(ccc)
      end
    end

    # Configure: check for a working C compiler.
    #
    # @param ccc [Array<String>]
    #   C compiler(s) to check for.
    #
    # @return [void]
    def check_c_compiler(ccc)
      if ccc.empty?
        # Default C compiler search array.
        ccc = %w[gcc clang]
      end
      cc = ccc.find do |cc|
        test_c_compiler(cc)
      end
    end

    # Test a C compiler.
    #
    # @param cc [String]
    #   C compiler to test.
    #
    # @return [Boolean]
    #   Whether the C compiler tested successfully.
    def test_c_compiler(cc)
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
