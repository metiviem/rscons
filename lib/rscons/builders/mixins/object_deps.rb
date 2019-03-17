module Rscons
  module Builders
    # Rscons::Buidlers::Mixins namespacing module.
    module Mixins
      # Functionality for builders which desire object or static library files
      # as inputs.
      module ObjectDeps

        # Register dependency builders to generate object files from @sources.
        #
        # @param builder_class [Builder]
        #   Builder class to use to build the object dependencies.
        #
        # @return [Array<String>]
        #   List of paths to the object or static library dependencies.
        def register_object_deps(builder_class)
          suffixes = @env.expand_varref(["${OBJSUFFIX}", "${LIBSUFFIX}"], @vars)
          @sources.map do |source|
            if source.end_with?(*suffixes)
              source
            else
              @env.register_dependency_build(@target, source, suffixes.first, @vars, builder_class)
            end
          end
        end

      end
    end
  end
end
