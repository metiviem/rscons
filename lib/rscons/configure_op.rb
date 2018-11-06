require "fileutils"

module Rscons
  # Class to manage a configure operation.
  class ConfigureOp

    # Exception raised when a configuration error occurs.
    class ConfigFailure < Exception; end

    # Create a ConfigureOp.
    #
    # @param work_dir [String]
    #   Work directory for configure operation.
    def initialize(work_dir)
      @work_dir = work_dir
      FileUtils.mkdir_p(@work_dir)
      @log_fh = File.open("#{@work_dir}/config.log", "wb")
    end

    # Close the log file handle.
    #
    # @return [void]
    def close
      @log_fh.close
      @log_fh = nil
    end

    # Check for a working C compiler.
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

    private

    # Test a C compiler.
    #
    # @param cc [String]
    #   C compiler to test.
    #
    # @return [Boolean]
    #   Whether the C compiler tested successfully.
    def test_c_compiler(cc)
    end

  end
end
