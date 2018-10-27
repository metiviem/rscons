module Rscons

  # The Script class encapsulates the state of a build script.
  class Script

    class Dsl
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

      # Enter configuration block.
      def configure(&block)
        cdsl = ConfigureDsl.new(@script)
        cdsl.instance_eval(&block)
      end
    end

    class ConfigureDsl < Dsl
      # Check for a C compiler.
      def check_c_compiler(*c_compilers)
        @script.check_c_compiler ||= []
        @script.check_c_compiler += c_compilers
      end

      # Check for a C++ compiler.
      def check_cxx_compiler(*cxx_compilers)
        @script.check_cxx_compiler ||= []
        @script.check_cxx_compiler += cxx_compilers
      end

      # Check for a D compiler.
      def check_d_compiler(*d_compilers)
        @script.check_d_compiler ||= []
        @script.check_d_compiler += d_compilers
      end

      # Check for a C header.
      def check_c_header(*c_headers)
        @script.check_c_headers ||= []
        @script.check_c_headers += c_headers
      end

      # Check for a C++ header.
      def check_cxx_header(*cxx_headers)
        @script.check_cxx_headers ||= []
        @script.check_cxx_headers += cxx_headers
      end

      # Check for a D import.
      def check_d_import(*d_imports)
        @script.check_d_imports ||= []
        @script.check_d_imports += d_imports
      end

      # Check for an executable.
      def check_executable(*executables)
        @script.check_executables ||= []
        @script.check_executables += executables
      end
    end

    # @return [String, nil]
    #   Project name.
    attr_accessor :project_name

    # @return [Array<String>]
    #   C compilers to check for.
    attr_accessor :check_c_compiler

    # @return [Array<String>]
    #   C++ compilers to check for.
    attr_accessor :check_cxx_compiler

    # @return [Array<String>]
    #   D compilers to check for.
    attr_accessor :check_d_compiler

    # @return [Array<String>]
    #   C headers to check for.
    attr_accessor :check_c_headers

    # @return [Array<String>]
    #   C++ headers to check for.
    attr_accessor :check_cxx_headers

    # @return [Array<String>]
    #   D imports to check for.
    attr_accessor :check_d_imports

    # @return [Array<String>]
    #   Executables to check for.
    attr_accessor :check_executables

    # @return [Boolean]
    #   Whether to autoconfigure if the user does not explicitly perform a
    #   configure operation before building (default: true).
    attr_accessor :autoconf

    # Construct a Script.
    def initialize
      @autoconf = true
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

  end

end
