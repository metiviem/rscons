module Rscons
  module Builders
    # A default Rscons builder that produces a static library archive.
    class Library < Builder

      Rscons.application.default_varset.append(
        'AR' => 'ar',
        'LIBSUFFIX' => '.a',
        'ARFLAGS' => ['rcs'],
        'ARCMD' => ['${AR}', '${ARFLAGS}', '${_TARGET}', '${_SOURCES}']
      )

      # Create an instance of the Builder to build a target.
      #
      # @param options [Hash]
      #   Options.
      # @option options [String] :target
      #   Target file name.
      # @option options [Array<String>] :sources
      #   Source file name(s).
      # @option options [Environment] :env
      #   The Environment executing the builder.
      # @option options [Hash,VarSet] :vars
      #   Extra construction variables.
      def initialize(options)
        super(options)
        suffixes = @env.expand_varref(["${OBJSUFFIX}", "${LIBSUFFIX}"], @vars)
        # Register builders to build each source to an object file or library.
        @objects = @env.register_builds(@target, @sources, suffixes, @vars)
      end

      # Run the builder to produce a build target.
      #
      # @param options [Hash] Builder run options.
      #
      # @return [String,false]
      #   Name of the target file on success or false on failure.
      def run(options)
        @vars["_TARGET"] = @target
        @vars["_SOURCES"] = @objects
        command = @env.build_command("${ARCMD}", @vars)
        standard_threaded_build("AR #{@target}", @target, command, @objects, @env, @cache)
      end

      # Finalize a build.
      #
      # @param options [Hash]
      #   Finalize options.
      #
      # @return [String, nil]
      #   The target name on success or nil on failure.
      def finalize(options)
        if options[:command_status]
          @cache.register_build(@target, options[:tc].command, @objects, @env)
          @target
        end
      end

    end
  end
end
