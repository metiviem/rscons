module Rscons

  # The Script class encapsulates the state of a build script.
  class Script

    # Global DSL methods.
    class GlobalDsl

      # Return a list of paths matching the specified pattern(s).
      #
      # A pattern can contain a "/**" component to recurse through directories.
      # If the pattern ends with "/**" then only the recursive list of
      # directories will be returned.
      #
      # Examples:
      # - "src/**": return all directories under "src", recursively (including
      #   "src" itself).
      # - "src/**/*": return all files and directories recursively under the src
      #   directory.
      # - "src/**/*.c": return all .c files recursively under the src directory.
      # - "dir/*/": return all directories in dir, but no files.
      #
      # @return [Array<String>] Paths matching the specified pattern(s).
      def glob(*patterns)
        require "pathname"
        patterns.reduce([]) do |result, pattern|
          if pattern.end_with?("/**")
            pattern += "/"
          end
          result += Dir.glob(pattern).map do |path|
            Pathname.new(path.gsub("\\", "/")).cleanpath.to_s
          end
        end.sort
      end

      # Return path components from the PATH variable.
      #
      # @return [Array<String>]
      #   Path components from the PATH variable.
      def path_components
        ENV["PATH"].split(File::PATH_SEPARATOR)
      end

      # Prepend a path component to the PATH variable.
      #
      # @param path [String]
      #   Path to prepend.
      #
      # @return [void]
      def path_prepend(path)
        path_set([File.expand_path(path)] + path_components)
      end

      # Append a path component to the PATH variable.
      #
      # @param path [String]
      #   Path to append.
      #
      # @return [void]
      def path_append(path)
        path_set(path_components + [File.expand_path(path)])
      end

      # Set the PATH variable.
      #
      # @param new_path [String, Array<String>]
      #   New PATH variable value as an array or string.
      #
      # @return [void]
      def path_set(new_path)
        if new_path.is_a?(Array)
          new_path = new_path.join(File::PATH_SEPARATOR)
        end
        ENV["PATH"] = new_path
      end

      # Invoke rscons in a subprocess for a subsidiary Rsconscript file.
      #
      # @param path [String]
      #   Path to subsidiary Rsconscript to execute, or path to subsidiary
      #   directory to run rscons in.
      # @param args[Array<String>]
      #   Arguments to pass to rscons subprocess.
      def rscons(path, *args)
        rscons_path = File.expand_path($0)
        path = File.expand_path(path)
        if File.directory?(path)
          command = [*args]
          dir = path
        else
          command = ["-f", path, *args]
          dir = File.dirname(path)
        end
        if File.exist?("#{dir}/rscons")
          rscons_path = "#{dir}/rscons"
        end
        command = [rscons_path] + command
        print_dir = dir != "." && dir != File.expand_path(Dir.pwd)
        if ENV["specs"] and not ENV["dist_specs"] # specs
          command = ["ruby", $LOAD_PATH.map {|p| ["-I", p]}, command].flatten # specs
        end # specs
        puts "rscons: Entering directory '#{dir}'" if print_dir
        result = system(*command, chdir: dir)
        puts "rscons: Leaving directory '#{dir}'" if print_dir
        unless result
          raise RsconsError.new("Failed command: " + command.join(" "))
        end
      end

      # Execute a shell command, exiting on failure.
      # The behavior to exit on failure is suppressed if the +:continue+
      # option is given.
      #
      # @overload sh(command, options = {})
      #   @param command [String, Array<String>]
      #     Command to execute. The command is executed and interpreted by the
      #     system shell when given as a single string. It is not passed to the
      #     system shell if the array size is greater than 1.
      #   @param options [Hash]
      #     Options.
      #   @option options [Boolean] :continue
      #     If set to +true+, rscons will continue executing afterward, even if
      #     the command fails.
      #
      # @overload sh(*command, options = {})
      #   @param command [String, Array<String>]
      #     Command to execute. The command is executed and interpreted by the
      #     system shell when given as a single string. It is not passed to the
      #     system shell if the array size is greater than 1.
      #   @param options [Hash]
      #     Options.
      #   @option options [Boolean] :continue
      #     If set to +true+, rscons will continue executing afterward, even if
      #     the command fails.
      def sh(*command)
        options = {}
        if command.last.is_a?(Hash)
          options = command.slice!(-1)
        end
        if command.size == 1 && command[0].is_a?(Array)
          command = command[0]
        end
        if Rscons.application.verbose
          if command.size > 1
            puts Util.command_to_s(command)
          else
            puts command[0]
          end
        end
        begin
          system(*command, exception: true)
        rescue StandardError => e
          message = "#{e.backtrace[2]}: #{e.message}"
          if options[:continue]
            Ansi.write($stderr, :red, message, :reset, "\n")
          else
            raise RsconsError.new(message)
          end
        end
      end

    end

    # Top-level DSL available to the Rsconscript.
    class Dsl < GlobalDsl
      # Create a Dsl.
      def initialize(script)
        @script = script
      end

      # Set the project name.
      def project_name(project_name)
        @script.project_name = project_name
      end

      # Whether to automatically configure (default true).
      def autoconf(autoconf)
        @script.autoconf = autoconf
      end

      # Enter build block.
      def build(&block)
        @script.operations["build"] = block
      end

      # Enter configuration block.
      def configure(&block)
        @script.operations["configure"] = block
      end
    end

    # DSL available to the 'configure' block.
    class ConfigureDsl < GlobalDsl
      # Create a ConfigureDsl.
      #
      # @param configure_op [ConfigureOp]
      #   The configure operation object.
      def initialize(configure_op)
        @configure_op = configure_op
      end

      [
        :check_c_compiler,
        :check_cxx_compiler,
        :check_d_compiler,
        :check_cfg,
        :check_c_header,
        :check_cxx_header,
        :check_d_import,
        :check_lib,
        :check_program,
      ].each do |method_name|
        define_method(method_name) do |*args|
          @configure_op.__send__(method_name, *args)
        end
      end

      # Perform a custom configuration check.
      #
      # @param message [String]
      #   Custom configuration check message (e.g. "Checking for foo").
      #   rscons will add "... " to the end of the message.
      # @yieldparam configure_op [ConfigureOp]
      #   {ConfigureOp} object.
      # @return [void]
      def custom_check(message, &block)
        $stdout.write(message + "... ")
        block[@configure_op]
      end
    end

    # @return [String, nil]
    #   Project name.
    attr_accessor :project_name

    # @return [Boolean]
    #   Whether to autoconfigure if the user does not explicitly perform a
    #   configure operation before building (default: true).
    attr_accessor :autoconf

    # @return [Hash]
    #   Operation lambdas.
    attr_reader :operations

    # Construct a Script.
    def initialize
      @autoconf = true
      @operations = {}
    end

    # Load a script from the specified file.
    #
    # @param path [String]
    #   File name of the rscons script to load.
    #
    # @return [void]
    def load(path)
      script_contents = File.read(path, mode: "rb")
      Dsl.new(self).instance_eval(script_contents, path, 1)
    end

    # Perform build operation.
    def build
      if build_proc = @operations["build"]
        build_proc.call
      end
    end

    # Perform configure operation.
    def configure(configure_op)
      if operation_lambda = @operations["configure"]
        cdsl = ConfigureDsl.new(configure_op)
        cdsl.instance_eval(&operation_lambda)
      end
    end

  end

end
