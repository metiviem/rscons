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
      @vars = VarSet.new
      @n_threads = determine_n_threads
    end

    # Run the specified operation.
    #
    # @param operation [String]
    #   The operation to perform (e.g. "clean", "configure", "build", etc...)
    #
    # @return [Integer]
    #   Process exit code (0 on success).
    def run(operation)
      # TODO
      0
    end

    private

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
