require "fileutils"
require "open3"

module Rscons
  # Class to manage a configure operation.
  class ConfigureOp

    # Exception raised when a configuration error occurs.
    class ConfigureFailure < Exception; end

    # Create a ConfigureOp.
    #
    # @param options [Hash]
    #   Optional parameters.
    # @option options [String] :build_dir
    #   Build directory.
    # @option options [String] :prefix
    #   Install prefix.
    # @option options [String] :project_name
    #   Project name.
    def initialize(options)
      # Default options.
      options[:build_dir] ||= "build"
      options[:prefix] ||= "/usr/local"
      @work_dir = "#{options[:build_dir]}/configure"
      FileUtils.mkdir_p(@work_dir)
      @log_fh = File.open("#{@work_dir}/config.log", "wb")
      cache = Cache.instance
      cache["failed_commands"] = []
      cache["configuration_data"] = {}
      cache["configuration_data"]["build_dir"] = options[:build_dir]
      cache["configuration_data"]["prefix"] = options[:prefix]
      if project_name = options[:project_name]
        Ansi.write($stdout, "Configuring ", :cyan, project_name, :reset, "...\n")
      else
        $stdout.puts "Configuring project..."
      end
      Ansi.write($stdout, "Setting build directory... ", :green, options[:build_dir], :reset, "\n")
      Ansi.write($stdout, "Setting prefix... ", :green, options[:prefix], :reset, "\n")
      store_merge("prefix" => options[:prefix])
    end

    # Close the log file handle.
    #
    # @param success [Boolean]
    #   Whether all configure operations were successful.
    #
    # @return [void]
    def close(success)
      @log_fh.close
      @log_fh = nil
      cache = Cache.instance
      cache["configuration_data"]["configured"] = success
      cache.write
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
      complete(cc ? 0 : 1, success_message: cc)
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
      complete(cc ? 0 : 1, success_message: cc)
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
      complete(dc ? 0 : 1, success_message: dc)
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
      complete(status, options)
    end

    # Check for a C header.
    def check_c_header(header_name, options = {})
      check_cpppath = [nil] + (options[:check_cpppath] || [])
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
        "_TARGET" => "#{@work_dir}/cfgtest.o",
        "_DEPFILE" => "#{@work_dir}/cfgtest.mf",
      }
      status = 1
      check_cpppath.each do |cpppath|
        env = BasicEnvironment.new
        if cpppath
          env["CPPPATH"] += Array(cpppath)
        end
        command = env.build_command("${CCCMD}", vars)
        _, _, status = log_and_test_command(command)
        if status == 0
          if cpppath
            store_append({"CPPPATH" => Array(cpppath)}, options)
          end
          break
        end
      end
      complete(status, options)
    end

    # Check for a C++ header.
    def check_cxx_header(header_name, options = {})
      check_cpppath = [nil] + (options[:check_cpppath] || [])
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
        "_TARGET" => "#{@work_dir}/cfgtest.o",
        "_DEPFILE" => "#{@work_dir}/cfgtest.mf",
      }
      status = 1
      check_cpppath.each do |cpppath|
        env = BasicEnvironment.new
        if cpppath
          env["CPPPATH"] += Array(cpppath)
        end
        command = env.build_command("${CXXCMD}", vars)
        _, _, status = log_and_test_command(command)
        if status == 0
          if cpppath
            store_append({"CPPPATH" => Array(cpppath)}, options)
          end
          break
        end
      end
      complete(status, options)
    end

    # Check for a D import.
    def check_d_import(d_import, options = {})
      check_d_import_path = [nil] + (options[:check_d_import_path] || [])
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
        "_TARGET" => "#{@work_dir}/cfgtest.o",
        "_DEPFILE" => "#{@work_dir}/cfgtest.mf",
      }
      status = 1
      check_d_import_path.each do |d_import_path|
        env = BasicEnvironment.new
        if d_import_path
          env["D_IMPORT_PATH"] += Array(d_import_path)
        end
        command = env.build_command("${DCCMD}", vars)
        _, _, status = log_and_test_command(command)
        if status == 0
          if d_import_path
            store_append({"D_IMPORT_PATH" => Array(d_import_path)}, options)
          end
          break
        end
      end
      complete(status, options)
    end

    # Check for a library.
    def check_lib(lib, options = {})
      check_libpath = [nil] + (options[:check_libpath] || [])
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
      status = 1
      check_libpath.each do |libpath|
        env = BasicEnvironment.new
        if libpath
          env["LIBPATH"] += Array(libpath)
        end
        command = env.build_command("${LDCMD}", vars)
        _, _, status = log_and_test_command(command)
        if status == 0
          if libpath
            store_append({"LIBPATH" => Array(libpath)}, options)
          end
          break
        end
      end
      if status == 0
        store_append({"LIBS" => [lib]}, options)
      end
      complete(status, options)
    end

    # Check for a executable program.
    def check_program(program, options = {})
      Ansi.write($stdout, "Checking for program '", :cyan, program, :reset, "'... ")
      path = Util.find_executable(program)
      complete(path ? 0 : 1, options.merge(success_message: path))
    end

    # Execute a test command and log the result.
    #
    # @return [String, String, Process::Status]
    #   stdout, stderr, status
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
    # @option options [String] :use
    #   A 'use' name. If specified, the construction variables are only applied
    #   to an Environment if the Environment is constructed with a matching
    #   `:use` value.
    def store_merge(vars, options = {})
      store_vars = store_common(options)
      store_vars["merge"] ||= {}
      vars.each_pair do |key, value|
        store_vars["merge"][key] = value
      end
    end

    # Store construction variables for appending into the Cache.
    #
    # @param vars [Hash]
    #   Hash containing the variables to append.
    # @param options [Hash]
    #   Options.
    # @option options [String] :use
    #   A 'use' name. If specified, the construction variables are only applied
    #   to an Environment if the Environment is constructed with a matching
    #   `:use` value.
    def store_append(vars, options = {})
      store_vars = store_common(options)
      store_vars["append"] ||= {}
      vars.each_pair do |key, value|
        if store_vars["append"][key].is_a?(Array) and value.is_a?(Array)
          store_vars["append"][key] += value
        else
          store_vars["append"][key] = value
        end
      end
    end

    # Store flags to be parsed into the Cache.
    #
    # @param flags [String]
    #   String containing the flags to parse.
    # @param options [Hash]
    #   Options.
    # @option options [String] :use
    #   A 'use' name. If specified, the construction variables are only applied
    #   to an Environment if the Environment is constructed with a matching
    #   `:use` value.
    def store_parse(flags, options = {})
      store_vars = store_common(options)
      store_vars["parse"] ||= []
      store_vars["parse"] << flags
    end

    # Perform processing common to several configure checks.
    #
    # @param status [Process::Status, Integer]
    #   Process exit code. 0 for success, non-zero for error.
    # @param options [Hash]
    #   Common check options.
    # @option options [Boolean] :fail
    #   Whether to fail configuration if the requested item is not found.
    #   This defaults to true if the :set_define option is not specified,
    #   otherwise defaults to false if :set_define option is specified.
    # @option options [String] :set_define
    #   A define to set (in CPPDEFINES) if the requested item is found.
    # @option options [String] :success_message
    #   Message to print on success (default "found").
    def complete(status, options)
      success_message = options[:success_message] || "found"
      fail_message = options[:fail_message] || "not found"
      if status == 0
        Ansi.write($stdout, :green, "#{success_message}\n")
        if options[:set_define]
          store_append("CPPDEFINES" => [options[:set_define]])
        end
      else
        should_fail =
          if options.has_key?(:fail)
            options[:fail]
          else
            !options[:set_define]
          end
        if should_fail
          Ansi.write($stdout, :red, "#{fail_message}\n")
          raise ConfigureFailure.new
        else
          Ansi.write($stdout, :yellow, "#{fail_message}\n")
        end
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
            printf("Success.\\n");
            return 0;
          }
        EOF
      end
      command = %W[#{cc} -o #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.c]
      merge = {"CC" => cc}
      _, _, status = log_and_test_command(command)
      if status == 0
        stdout, _, status = log_and_test_command(["#{@work_dir}/cfgtest.exe"])
        if status == 0 and stdout =~ /Success/
          store_merge(merge)
          true
        end
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
            cout << "Success." << endl;
            return 0;
          }
        EOF
      end
      command = %W[#{cc} -o #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.cxx]
      merge = {"CXX" => cc}
      _, _, status = log_and_test_command(command)
      if status == 0
        stdout, _, status = log_and_test_command(["#{@work_dir}/cfgtest.exe"])
        if status == 0 and stdout =~ /Success/
          store_merge(merge)
          true
        end
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
            writeln("Success.");
            return 0;
          }
        EOF
      end
      [:gdc, :ldc2].find do |dc_test|
        case dc_test
        when :gdc
          command = %W[#{dc} -o #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.d]
          merge = {"DC" => dc}
        when :ldc2
          command = %W[#{dc} -of #{@work_dir}/cfgtest.exe #{@work_dir}/cfgtest.d]
          env = BasicEnvironment.new
          merge = {
            "DC" => dc,
            "DCCMD" => env["DCCMD"].map {|e| if e == "-o"; "-of"; else; e; end},
            "LDCMD" => env["LDCMD"].map {|e| if e == "-o"; "-of"; else; e; end},
            "DDEPGEN" => ["-deps=${_DEPFILE}"],
          }
          if RUBY_PLATFORM =~ /mingw/
            # ldc2 on Windows expect an object file suffix of .obj.
            merge["OBJSUFFIX"] = %w[.obj]
          end
        end
        _, _, status = log_and_test_command(command)
        if status == 0
          stdout, _, status = log_and_test_command(["#{@work_dir}/cfgtest.exe"])
          if status == 0 and stdout =~ /Success/
            store_merge(merge)
            true
          end
        end
      end
    end

    # Common functionality for all store methods.
    #
    # @param options [Hash]
    #   Options.
    #
    # @return [Hash]
    #   Configuration Hash for storing vars.
    def store_common(options)
      if options[:use] == false
        {}
      else
        usename =
          if options[:use]
            options[:use].to_s
          else
            "_default_"
          end
        cache = Cache.instance
        cache["configuration_data"]["vars"] ||= {}
        cache["configuration_data"]["vars"][usename] ||= {}
      end
    end

  end
end
