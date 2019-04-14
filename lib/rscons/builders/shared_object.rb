module Rscons
  module Builders
    # A default Rscons builder which knows how to produce an object file which
    # is capable of being linked into a shared library from various types of
    # source files.
    class SharedObject < Builder
      include Mixins::Object

      class << self
        def extra_path
          "_shared"
        end
      end
    end
  end
end
