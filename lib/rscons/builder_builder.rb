module Rscons
  # A class that knows how to build an instance of another Builder class when
  # it is needed.
  class BuilderBuilder

    # Create a BuilderBuilder.
    #
    # @param builder_class [Class]
    #   The {Builder} class to be instantiated.
    # @param builder_args [Array]
    #   Any extra arguments to be passed to the builder class.
    # @param builder_block [Proc, nil]
    #   Optional block to be passed to the {Builder} class's #new method.
    def initialize(builder_class, *builder_args, &builder_block)
      @builder_class = builder_class
      @builder_args = builder_args
      @builder_block = builder_block
    end

    # Act like a regular {Builder} class object but really instantiate the
    # requested {Builder} class, potentially with extra arguments and a block.
    def new(*args)
      @builder_class.new(*@builder_args, *args, &@builder_block)
    end

  end
end
