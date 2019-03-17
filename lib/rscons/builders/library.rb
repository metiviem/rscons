module Rscons
  module Builders
    # A default Rscons builder that produces a static library archive.
    class Library < Builder

      # Create an instance of the Builder to build a target.
      def initialize(options)
        super(options)
        suffixes = @env.expand_varref(["${OBJSUFFIX}", "${LIBSUFFIX}"], @vars)
        @objects = @sources.map do |source|
          if source.end_with?(*suffixes)
            source
          else
            @env.register_dependency_build(@target, source, suffixes.first, @vars, Object)
          end
        end
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
