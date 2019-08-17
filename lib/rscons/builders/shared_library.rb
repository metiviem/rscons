module Rscons
  module Builders
    # A default Rscons builder that knows how to link object files into a
    # shared library.
    class SharedLibrary < Builder

      include Mixins::ObjectDeps
      include Mixins::Program

      class << self
        # Custom new method which will delegate to the correct class depending
        # on the options specified.
        def new(options, *more)
          libprefix = options[:env].expand_varref("${SHLIBPREFIX}", options[:vars])
          unless File.basename(options[:target]).start_with?(libprefix)
            options[:target] = options[:target].sub!(%r{^(.*/)?([^/]+)$}, "\\1#{libprefix}\\2")
          end
          unless File.basename(options[:target])["."]
            options[:target] += options[:env].expand_varref("${SHLIBSUFFIX}", options[:vars])
          end
          if options[:vars][:direct]
            SharedObject.new(options, *more)
          else
            super
          end
        end
      end

      # Create an instance of the Builder to build a target.
      def initialize(options)
        super(options)
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
