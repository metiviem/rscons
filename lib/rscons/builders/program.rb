module Rscons
  module Builders
    # A default Rscons builder that knows how to link object files into an
    # executable program.
    class Program < Builder

      include Mixins::ObjectDeps
      include Mixins::Program

      # Create an instance of the Builder to build a target.
      def initialize(options)
        super(options)
        unless File.basename(@target)["."]
          @target += @env.expand_varref("${PROGSUFFIX}", @vars)
        end
        @objects = register_object_deps(Object)
      end

      private

      def default_ld
        "${CC}"
      end

      def ld_var
        "LD"
      end

    end
  end
end
