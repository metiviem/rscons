module Rscons
  module Builders
    # A default Rscons builder that knows how to link object files into a
    # shared library.
    class SharedLibrary < Builder

      include Mixins::ObjectDeps
      include Mixins::Program

      # Create an instance of the Builder to build a target.
      def initialize(options)
        super(options)
        libprefix = @env.expand_varref("${SHLIBPREFIX}", @vars)
        unless File.basename(@target).start_with?(libprefix)
          @target = @target.sub!(%r{^(.*/)?([^/]+)$}, "\\1#{libprefix}\\2")
        end
        unless File.basename(@target)["."]
          @target += @env.expand_varref("${SHLIBSUFFIX}", @vars)
        end
        @objects = register_object_deps(SharedObject)
      end

      private

      def default_ld
        "${SHCC}"
      end

      def ld_var
        "SHLD"
      end

    end
  end
end
