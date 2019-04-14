module Rscons
  module Builders
    # A default Rscons builder that knows how to link object files into an
    # executable program.
    class Program < Builder

      include Mixins::ObjectDeps
      include Mixins::Program

      class << self
        def new(options, *more)
          unless File.basename(options[:target])["."]
            options[:target] += options[:env].expand_varref("${PROGSUFFIX}", options[:vars])
          end
          if options[:vars][:direct]
            Object.new(options, *more)
          else
            super
          end
        end
      end

      # Create an instance of the Builder to build a target.
      def initialize(options)
        super(options)
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
