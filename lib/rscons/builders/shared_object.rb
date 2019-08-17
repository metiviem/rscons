module Rscons
  module Builders
    # A default Rscons builder which knows how to produce an object file which
    # is capable of being linked into a shared library from various types of
    # source files.
    class SharedObject < Builder
      include Mixins::Object

      class << self
        # Content component to add to build path to separate objects built
        # using this builder from others.
        def extra_path
          "_shared"
        end
      end
    end
  end
end
