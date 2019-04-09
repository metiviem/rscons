module Rscons
  module Builders
    # A default Rscons builder which knows how to produce an object file from
    # various types of source files.
    class Object < Builder
      include Mixins::Object
    end
  end
end
