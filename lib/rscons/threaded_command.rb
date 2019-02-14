module Rscons
  # If a builder returns an instance of this class from its #run method, then
  # Rscons will execute the command specified in a thread and allow other
  # builders to continue executing in parallel.
  class ThreadedCommand

    # @return [Array<String>]
    #   The command to execute.
    attr_reader :command

    # @return [String]
    #   Short description of the command. This will be printed to standard
    #   output if the Environment's echo mode is :short.
    attr_reader :short_description

    # @return [Hash]
    #   Environment Hash to pass to Kernel#system.
    attr_reader :system_env

    # @return [Hash]
    #   Options Hash to pass to Kernel#system.
    attr_reader :system_options

    # @return [Hash]
    #   Field for Rscons to store the build operation while this threaded
    #   command is executing.
    attr_accessor :build_operation

    # @return [Builder]
    #   {Builder} executing this command.
    attr_accessor :builder

    # @return [Thread]
    #   The thread waiting on this command to terminate.
    attr_accessor :thread

    # Create a ThreadedCommand object.
    #
    # @param command [Array<String>]
    #   The command to execute.
    # @param options [Hash]
    #   Optional parameters.
    # @option options [Object] :builder_info
    #   Arbitrary object to store builder-specific info. This object value will
    #   be passed back into the builder's #finalize method.
    # @option options [String] :short_description
    #   Short description of the command. This will be printed to standard
    #   output if the Environment's echo mode is :short.
    # @option options [Hash] :system_env
    #   Environment Hash to pass to Kernel#system.
    # @option options [Hash] :system_options
    #   Options Hash to pass to Kernel#system.
    def initialize(command, options = {})
      @command = command
      @short_description = options[:short_description]
      @system_env = options[:system_env]
      @system_options = options[:system_options]
    end

  end
end
