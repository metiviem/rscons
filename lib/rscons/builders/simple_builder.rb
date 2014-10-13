module Rscons
  module Builders
    # A Generic builder class whose name and operation is defined at
    # instantiation.
    class SimpleBuilder < Builder
      # The name of this builder when registered in an environment
      attr_reader :name

      # Create a new builder with the given name and action.
      #
      # @param name  [String,Symbol] The name of the builder when registered.
      # @param block [Block]
      #   The action to perform when the builder is processed. The provided
      #   block must return the target file on success or false on failure.
      #   The provided block should have the same signature as {Builder#run}.
      def initialize(name, &block)
        @name  = name.to_s
        @block = block
      end

      # Run the builder to produce a build target.
      #
      # @param target [String] Target file name.
      # @param sources [Array<String>] Source file name(s).
      # @param cache [Cache] The Cache object.
      # @param env [Environment] The Environment executing the builder.
      # @param vars [Hash,VarSet] Extra construction variables.
      #
      # @return [String,false]
      #   Name of the target file on success or false on failure.
      def run(target, sources, cache, env, vars)
        @block.call(target, sources, cache, env, vars)
      end
    end
  end
end

