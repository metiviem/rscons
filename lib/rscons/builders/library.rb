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
      def initialize(options)
        super(options)
        suffixes = @env.expand_varref(["${OBJSUFFIX}", "${LIBSUFFIX}"], @vars)
        # Register builders to build each source to an object file or library.
        @objects = @env.register_builds(@target, @sources, suffixes, @vars)
      end

      # Run the builder to produce a build target.
      def run(options)
        if @command
          finalize_command(sources: @objects)
          true
        else
          @vars["_TARGET"] = @target
          @vars["_SOURCES"] = @objects
          command = @env.build_command("${ARCMD}", @vars)
          standard_command("Building static library archive => #{@target}", command, sources: @objects)
        end
      end

    end
  end
end
