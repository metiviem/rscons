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

      # Enter build block.
      def build(&block)
        @script.operations["build"] = block
      end

      # Enter configuration block.
      def configure(&block)
        @script.operations["configure"] = block
      end
    end

    class ConfigureDsl
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
