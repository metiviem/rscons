module Rscons
  module Builders
    # A default Rscons builder that produces a static library archive.
    class Library < Builder

      include Mixins::ObjectDeps

      # Create an instance of the Builder to build a target.
      def initialize(options)
        super(options)
        @objects = register_object_deps(Object)
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
          standard_command("Building static library archive <target>#{@target}<reset>", command, sources: @objects)
        end
      end

    end
  end
end
