require "fileutils"
require "open3"

module Rscons
  # Class to manage a configure operation.
  class ConfigureOp

    # Exception raised when a configuration error occurs.
    class ConfigureFailure < Exception; end

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
      $stdout.write("Checking for C compiler... ")
      if ccc.empty?
        # Default C compiler search array.
        ccc = %w[gcc clang]
      end
      cc = ccc.find do |cc|
        test_c_compiler(cc)
      end
      if cc
        Ansi.write($stdout, :green, cc, "\n")
      else
        Ansi.write($stdout, :red, "not found\n")
        raise ConfigureFailure.new
      end
    end

    # Check for a working C++ compiler.
    #
    # @param ccc [Array<String>]
    #   C++ compiler(s) to check for.
    #
    # @return [void]
    def check_cxx_compiler(ccc)
      $stdout.write("Checking for C++ compiler... ")
      if ccc.empty?
        # Default C++ compiler search array.
        ccc = %w[g++ clang++]
      end
      cc = ccc.find do |cc|
        test_cxx_compiler(cc)
      end
      if cc
        Ansi.write($stdout, :green, cc, "\n")
      else
        Ansi.write($stdout, :red, "not found\n")
        raise ConfigureFailure.new
      end
    end

    # Check for a working D compiler.
    #
    # @param cdc [Array<String>]
    #   D compiler(s) to check for.
    #
    # @return [void]
    def check_d_compiler(cdc)
      $stdout.write("Checking for D compiler... ")
      if cdc.empty?
        # Default D compiler search array.
        cdc = %w[gdc ldc2]
      end
      dc = cdc.find do |dc|
        test_d_compiler(dc)
      end
      if dc
        Ansi.write($stdout, :green, dc, "\n")
      else
        Ansi.write($stdout, :red, "not found\n")
        raise ConfigureFailure.new
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
      File.open("#{@work_dir}/cfgtest.c", "wb") do |fh|
        fh.puts <<-EOF
          #include <stdio.h>
          int main(int argc, char * argv[]) {
            printf("Hello.\\n");
            return 0;
          }
        EOF
      end
      case cc
      when "gcc"
        command = %W[gcc -o #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.c]
      when "clang"
        command = %W[clang -o #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.c]
      else
        $stderr.puts "Unknown C compiler (#{cc})"
        raise ConfigureFailure.new
      end
      _, _, status = log_and_test_command(command)
      status == 0
    end

    # Test a C++ compiler.
    #
    # @param cc [String]
    #   C++ compiler to test.
    #
    # @return [Boolean]
    #   Whether the C++ compiler tested successfully.
    def test_cxx_compiler(cc)
      File.open("#{@work_dir}/cfgtest.cxx", "wb") do |fh|
        fh.puts <<-EOF
          #include <iostream>
          using namespace std;
          int main(int argc, char * argv[]) {
            cout << "Hello." << endl;
            return 0;
          }
        EOF
      end
      case cc
      when "g++"
        command = %W[g++ -o #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.cxx]
      when "clang++"
        command = %W[clang++ -o #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.cxx]
      else
        $stderr.puts "Unknown C++ compiler (#{cc})"
        raise ConfigureFailure.new
      end
      _, _, status = log_and_test_command(command)
      status == 0
    end

    # Test a D compiler.
    #
    # @param dc [String]
    #   D compiler to test.
    #
    # @return [Boolean]
    #   Whether the D compiler tested successfully.
    def test_d_compiler(dc)
      File.open("#{@work_dir}/cfgtest.d", "wb") do |fh|
        fh.puts <<-EOF
          import std.stdio;
          int main() {
            writeln("Hello.");
            return 0;
          }
        EOF
      end
      case dc
      when "gdc"
        command = %W[gdc -o #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.d]
      when "ldc2"
        command = %W[ldc2 -of=#{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.d]
      else
        $stderr.puts "Unknown D compiler (#{dc})"
        raise ConfigureFailure.new
      end
      _, _, status = log_and_test_command(command)
      status == 0
    end

    # Execute a test command and log the result.
    def log_and_test_command(command)
      begin
        @log_fh.puts("Command: #{command.join(" ")}")
        stdout, stderr, status = Open3.capture3(*command)
        @log_fh.puts("Exit status: #{status.to_i}")
        @log_fh.write(stdout)
        @log_fh.write(stderr)
        [stdout, stderr, status]
      rescue Errno::ENOENT
        ["", "", 127]
      end
    end

  end
end
