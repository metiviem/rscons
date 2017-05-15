module Rscons
  # If a builder returns an instance of this class from its #run method, then
  # Rscons will execute the command specified in a thread and allow other
  # builders to continue executing in parallel.
  class ThreadedCommand

    # @return [Array<String>]
    #   The command to execute.
    attr_reader :command

    # @return [Object]
    #   Arbitrary object to store builder-specific info. This object value will
    #   be passed back into the builder's #finalize method.
    attr_reader :builder_info

    # Create a ThreadedCommand object.
    #
    # @param command [Array<String>]
    #   The command to execute.
    # @param options [Hash]
    #   Optional parameters.
    # @option options [Object] :builder_info
    #   Arbitrary object to store builder-specific info. This object value will
    #   be passed back into the builder's #finalize method.
    def initialize(command, options = {})
      @command = command
      @builder_info = options[:builder_info]
    end

  end
end
