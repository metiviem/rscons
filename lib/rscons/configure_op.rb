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
    def check_c_compiler(*ccc)
      $stdout.write("Checking for C compiler... ")
      if ccc.empty?
        # Default C compiler search array.
        ccc = %w[gcc clang]
      end
      cc = ccc.find do |cc|
        test_c_compiler(cc)
      end
      common_config_checks(cc ? 0 : 1, success_message: cc)
    end

    # Check for a working C++ compiler.
    #
    # @param ccc [Array<String>]
    #   C++ compiler(s) to check for.
    #
    # @return [void]
    def check_cxx_compiler(*ccc)
      $stdout.write("Checking for C++ compiler... ")
      if ccc.empty?
        # Default C++ compiler search array.
        ccc = %w[g++ clang++]
      end
      cc = ccc.find do |cc|
        test_cxx_compiler(cc)
      end
      common_config_checks(cc ? 0 : 1, success_message: cc)
    end

    # Check for a working D compiler.
    #
    # @param cdc [Array<String>]
    #   D compiler(s) to check for.
    #
    # @return [void]
    def check_d_compiler(*cdc)
      $stdout.write("Checking for D compiler... ")
      if cdc.empty?
        # Default D compiler search array.
        cdc = %w[gdc ldc2]
      end
      dc = cdc.find do |dc|
        test_d_compiler(dc)
      end
      common_config_checks(dc ? 0 : 1, success_message: dc)
    end

    # Check for a package or configure program output.
    def check_cfg(options = {})
      if package = options[:package]
        Ansi.write($stdout, "Checking for package '", :cyan, package, :reset, "'... ")
      elsif program = options[:program]
        Ansi.write($stdout, "Checking '", :cyan, program, :reset, "'... ")
      end
      program ||= "pkg-config"
      args = options[:args] || %w[--cflags --libs]
      command = [program, *args, package].compact
      stdout, _, status = log_and_test_command(command)
      if status == 0
        store_parse(stdout, options)
      end
      common_config_checks(status, options)
    end

    # Check for a C header.
    def check_c_header(header_name, options = {})
      Ansi.write($stdout, "Checking for C header '", :cyan, header_name, :reset, "'... ")
      File.open("#{@work_dir}/cfgtest.c", "wb") do |fh|
        fh.puts <<-EOF
          #include "#{header_name}"
          int main(int argc, char * argv[]) {
            return 0;
          }
        EOF
      end
      vars = {
        "LD" => "${CC}",
        "_SOURCES" => "#{@work_dir}/cfgtest.c",
        "_TARGET" => "#{@work_dir}/cfgtest.exe",
      }
      command = Environment.new.build_command("${LDCMD}", vars)
      _, _, status = log_and_test_command(command)
      common_config_checks(status, options)
    end

    # Check for a C++ header.
    def check_cxx_header(header_name, options = {})
      Ansi.write($stdout, "Checking for C++ header '", :cyan, header_name, :reset, "'... ")
      File.open("#{@work_dir}/cfgtest.cxx", "wb") do |fh|
        fh.puts <<-EOF
          #include "#{header_name}"
          int main(int argc, char * argv[]) {
            return 0;
          }
        EOF
      end
      vars = {
        "LD" => "${CXX}",
        "_SOURCES" => "#{@work_dir}/cfgtest.cxx",
        "_TARGET" => "#{@work_dir}/cfgtest.exe",
      }
      command = Environment.new.build_command("${LDCMD}", vars)
      _, _, status = log_and_test_command(command)
      common_config_checks(status, options)
    end

    # Check for a D import.
    def check_d_import(d_import, options = {})
      Ansi.write($stdout, "Checking for D import '", :cyan, d_import, :reset, "'... ")
      File.open("#{@work_dir}/cfgtest.d", "wb") do |fh|
        fh.puts <<-EOF
          import #{d_import};
          int main() {
            return 0;
          }
        EOF
      end
      vars = {
        "LD" => "${DC}",
        "_SOURCES" => "#{@work_dir}/cfgtest.d",
        "_TARGET" => "#{@work_dir}/cfgtest.exe",
      }
      command = Environment.new.build_command("${LDCMD}", vars)
      _, _, status = log_and_test_command(command)
      common_config_checks(status, options)
    end

    # Check for a library.
    def check_lib(lib, options = {})
      Ansi.write($stdout, "Checking for library '", :cyan, lib, :reset, "'... ")
      File.open("#{@work_dir}/cfgtest.c", "wb") do |fh|
        fh.puts <<-EOF
          int main(int argc, char * argv[]) {
            return 0;
          }
        EOF
      end
      vars = {
        "LD" => "${CC}",
        "LIBS" => [lib],
        "_SOURCES" => "#{@work_dir}/cfgtest.c",
        "_TARGET" => "#{@work_dir}/cfgtest.exe",
      }
      command = Environment.new.build_command("${LDCMD}", vars)
      _, _, status = log_and_test_command(command)
      common_config_checks(status, options)
    end

    # Check for a executable program.
    def check_program(program, options = {})
      Ansi.write($stdout, "Checking for program '", :cyan, program, :reset, "'... ")
      found = false
      if program["/"] or program["\\"]
        if File.file?(program) and File.executable?(program)
          found = true
          success_message = program
        end
      else
        path_entries = ENV["PATH"].split(File::PATH_SEPARATOR)
        path_entries.find do |path_entry|
          if path = test_path_for_executable(path_entry, program)
            found = true
            success_message = path
          end
        end
      end
      common_config_checks(found ? 0 : 1, options.merge(success_message: success_message))
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
        merge = {"CC" => "gcc"}
      when "clang"
        command = %W[clang -o #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.c]
        merge = {"CC" => "clang"}
      else
        $stderr.puts "Unknown C compiler (#{cc})"
        raise ConfigureFailure.new
      end
      _, _, status = log_and_test_command(command)
      if status == 0
        store_merge(merge)
        true
      end
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
        merge = {"CXX" => "g++"}
      when "clang++"
        command = %W[clang++ -o #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.cxx]
        merge = {"CXX" => "clang++"}
      else
        $stderr.puts "Unknown C++ compiler (#{cc})"
        raise ConfigureFailure.new
      end
      _, _, status = log_and_test_command(command)
      if status == 0
        store_merge(merge)
        true
      end
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
        merge = {"DC" => "gdc"}
      when "ldc2"
        command = %W[ldc2 -of #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.d]
        env = Environment.new
        merge = {
          "DC" => "ldc2",
          "DCCMD" => env["DCCMD"].map {|e| if e == "-o"; "-of"; else; e; end},
          "LDCMD" => env["LDCMD"].map {|e| if e == "-o"; "-of"; else; e; end},
        }
      else
        $stderr.puts "Unknown D compiler (#{dc})"
        raise ConfigureFailure.new
      end
      _, _, status = log_and_test_command(command)
      if status == 0
        store_merge(merge)
        true
      end
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

    # Store construction variables for merging into the Cache.
    #
    # @param vars [Hash]
    #   Hash containing the variables to merge.
    # @param options [Hash]
    #   Options.
    def store_merge(vars, options = {})
      usename = options[:use] || "_default_"
      cache = Cache.instance
      cache.configuration_data["vars"] ||= {}
      cache.configuration_data["vars"][usename] ||= {}
      cache.configuration_data["vars"][usename]["merge"] ||= {}
      vars.each_pair do |key, value|
        cache.configuration_data["vars"][usename]["merge"][key] = value
      end
    end

    # Store construction variables for appending into the Cache.
    #
    # @param vars [Hash]
    #   Hash containing the variables to append.
    # @param options [Hash]
    #   Options.
    def store_append(vars, options = {})
      usename = options[:use] || "_default_"
      cache = Cache.instance
      cache.configuration_data["vars"] ||= {}
      cache.configuration_data["vars"][usename] ||= {}
      cache.configuration_data["vars"][usename]["append"] ||= {}
      vars.each_pair do |key, value|
        if cache.configuration_data["vars"][usename]["append"][key].is_a?(Array) and value.is_a?(Array)
          cache.configuration_data["vars"][usename]["append"][key] += value
        else
          cache.configuration_data["vars"][usename]["append"][key] = value
        end
      end
    end

    # Store flags to be parsed into the Cache.
    #
    # @param flags [String]
    #   String containing the flags to parse.
    # @param options [Hash]
    #   Options.
    def store_parse(flags, options = {})
      usename = options[:use] || "_default_"
      cache = Cache.instance
      cache.configuration_data["vars"] ||= {}
      cache.configuration_data["vars"][usename] ||= {}
      cache.configuration_data["vars"][usename]["parse"] ||= []
      cache.configuration_data["vars"][usename]["parse"] << flags
    end

    # Perform processing common to several configure checks.
    #
    # @param status [Process::Status, Integer]
    #   Process exit code.
    # @param options [Hash]
    #   Common check options.
    # @option options [Boolean] :fail
    #   Whether to fail configuration if the requested item is not found.
    # @option options [String] :set_define
    #   A define to set (in CPPDEFINES) if the requested item is found.
    # @option options [String] :success_message
    #   Message to print on success (default "found").
    def common_config_checks(status, options)
      success_message = options[:success_message] || "found"
      if status == 0
        Ansi.write($stdout, :green, "#{success_message}\n")
      else
        if options.has_key?(:fail) and not options[:fail]
          Ansi.write($stdout, :yellow, "not found\n")
        else
          Ansi.write($stdout, :red, "not found\n")
          raise ConfigureFailure.new
        end
      end
      if options[:set_define]
        store_append("CPPDEFINES" => options[:set_define])
      end
    end

    # Check if a directory contains a certain executable.
    #
    # @param path_entry [String]
    #   Directory to look in.
    # @param executable [String]
    #   Executable to look for.
    def test_path_for_executable(path_entry, executable)
      is_executable = lambda do |path|
        File.file?(path) and File.executable?(path)
      end
      if RbConfig::CONFIG["host_os"] =~ /mswin|windows|mingw/i
        executable = executable.downcase
        dir_entries = Dir.entries(path_entry)
        dir_entries.find do |entry|
          path = "#{path_entry}/#{entry}"
          entry = entry.downcase
          if ((entry == executable) or
              (entry == "#{executable}.exe") or
              (entry == "#{executable}.com") or
              (entry == "#{executable}.bat")) and is_executable[path]
            return path
          end
        end
      else
        path = "#{path_entry}/#{executable}"
        return path if is_executable[path]
      end
    end

  end
end
