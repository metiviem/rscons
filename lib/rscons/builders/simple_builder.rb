module Rscons
  module Builders
    # A Generic builder which has its operation is defined at instantiation.
    #
    # @since 1.8.0
    class SimpleBuilder < Builder

      # Create a new builder with the given action.
      #
      # @param run_proc [Proc]
      #   A Proc to execute when the builder runs. The provided block must
      #   provide the have the same signature as {Builder#run}.
      def initialize(&run_proc)
        @run_proc = run_proc
      end

      # Run the builder to produce a build target.
      #
      # Method signature described by {Builder#run}.
      def run(*args)
        @run_proc.call(*args)
      end

    end
  end
end
