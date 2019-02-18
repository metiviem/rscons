module Rscons
  # Class to keep track of system commands that builders need to execute.
  # Rscons will manage scheduling these commands to be run in separate threads.
  class Command

    # @return [Builder]
    #   {Builder} executing this command.
    attr_reader :builder

    # @return [Array<String>]
    #   The command to execute.
    attr_reader :command

    # @return [nil, true, false]
    #   true if the command gives zero exit status.
    #   false if the command gives non-zero exit status.
    #   nil if command execution fails.
    attr_accessor :status

    # @return [Hash]
    #   Environment Hash to pass to Kernel#system.
    attr_reader :system_env

    # @return [Hash]
    #   Options Hash to pass to Kernel#system.
    attr_reader :system_options

    # @return [Thread]
    #   The thread waiting on this command to terminate.
    attr_reader :thread

    # Create a ThreadedCommand object.
    #
    # @param command [Array<String>]
    #   The command to execute.
    # @param builder [Builder]
    #   The {Builder} executing this command.
    # @param options [Hash]
    #   Optional parameters.
    # @option options [Hash] :system_env
    #   Environment Hash to pass to Kernel#system.
    # @option options [Hash] :system_options
    #   Options Hash to pass to Kernel#system.
    def initialize(command, builder, options = {})
      @command = command
      @builder = builder
      @system_env = options[:system_env]
      @system_options = options[:system_options]
    end

    # Start a thread to run the command.
    #
    # @return [Thread]
    #   The Thread created to run the command.
    def run
      env_args = @system_env ? [@system_env] : []
      options_args = @system_options ? [@system_options] : []
      system_args = [*env_args, *Rscons.command_executer, *@command, *options_args]

      @thread = Thread.new do
        system(*system_args)
      end
    end

  end
end
