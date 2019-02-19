require "fileutils"

module Rscons
  # Namespace module in which to store builders for convenient grouping
  module Builders; end

  # Class to hold an object that knows how to build a certain type of file.
  class Builder

    class << self
      # Return the name of the builder.
      #
      # If not overridden this defaults to the last component of the class name.
      #
      # @return [String] The name of the builder.
      def name
        super.split(":").last
      end

      # Return a set of build features that this builder provides.
      #
      # @return [Array<String>]
      #   Set of build features that this builder provides.
      def features
        []
      end

      # Return whether this builder object is capable of producing a given target
      # file name from a given source file name.
      #
      # @param target [String]
      #   The target file name.
      # @param source [String]
      #   The source file name.
      # @param env [Environment]
      #   The Environment.
      #
      # @return [Boolean]
      #   Whether this builder object is capable of producing a given target
      #   file name from a given source file name.
      def produces?(target, source, env)
        false
      end
    end

    # @return [String, Symbol]
    #   Target file name.
    attr_accessor :target

    # @return [Array<String>]
    #   Source file name(s).
    attr_accessor :sources

    # @return [Cache]
    #   Cache instance.
    attr_accessor :cache

    # @return [Environment]
    #   The {Environment} performing the build operation.
    attr_accessor :env

    # @return [Hash, VarSet]
    #   Construction variables used to perform the build operation.
    attr_accessor :vars

    # Create an instance of the Builder to build a target.
    #
    # @param options [Hash]
    #   Options.
    # @option options [String, Symbol] :target
    #   Target file name.
    # @option options [Array<String>] :sources
    #   Source file name(s).
    # @option options [Cache] :cache
    #   The Cache object.
    # @option options [Environment] :env
    #   The Environment executing the builder.
    # @option options [Hash,VarSet] :vars
    #   Extra construction variables.
    def initialize(options)
      @target = options[:target]
      @sources = options[:sources]
      @cache = options[:cache]
      @env = options[:env]
      @vars = options[:vars]
    end

    # Return the name of the builder.
    #
    # If not overridden this defaults to the last component of the class name.
    #
    # @return [String] The name of the builder.
    def name
      self.class.name
    end

    # Manually record a given build target as depending on the specified files.
    #
    # @param user_deps [Array<String>]
    #   Dependency files.
    #
    # @return [void]
    def depends(*user_deps)
      @env.depends(@target, *user_deps)
    end

    # Run the builder to produce a build target.
    #
    # @param options [Hash]
    #   Run options.
    #
    # @return [Object]
    #   If the build operation fails, this method should return +false+.
    #   If the build operation succeeds, this method should return +true+.
    #   If the build operation is not yet complete and is waiting on other
    #   operations, this method should return the return value from the
    #   {#wait_for} method.
    def run(options)
      raise "This method must be overridden in a subclass"
    end

    # Print the builder run message, depending on the Environment's echo mode.
    #
    # @param short_description [String]
    #   Builder short description, printed if the echo mode is :short, or if
    #   there is no command.
    # @param command [Array<String>]
    #   Builder command, printed if the echo mode is :command.
    #
    # @return [void]
    def print_run_message(short_description, command)
      @env.print_builder_run_message(self, short_description, command)
    end

    # Create a {Command} object to execute the build command in a thread.
    #
    # @param short_description [String]
    #   Short description of build action to be printed when env.echo ==
    #   :short.
    # @param command [Array<String>]
    #   The command to execute.
    # @param options [Hash]
    #   Options.
    # @option options [String] :stdout
    #   File name to redirect standard output to.
    #
    # @return [Object]
    #   Return value for {#run} method.
    def register_command(short_description, command, options = {})
      command_options = {}
      if options[:stdout]
        command_options[:system_options] = {out: options[:stdout]}
      end
      print_run_message(short_description, @command)
      wait_for(Command.new(command, self, command_options))
    end

    # Check if the cache is up to date for the target and if not create a
    # {Command} object to execute the build command in a thread.
    #
    # @param short_description [String]
    #   Short description of build action to be printed when env.echo ==
    #   :short.
    # @param command [Array<String>]
    #   The command to execute.
    # @param options [Hash]
    #   Options.
    # @option options [Array<String>] :sources
    #   Sources to override @sources.
    # @option options [String] :stdout
    #   File name to redirect standard output to.
    #
    # @return [Object]
    #   Return value for {#run} method.
    def standard_command(short_description, command, options = {})
      @command = command
      sources = options[:sources] || @sources
      if @cache.up_to_date?(@target, @command, sources, @env)
        true
      else
        unless Rscons.phony_target?(@target)
          @cache.mkdir_p(File.dirname(@target))
          FileUtils.rm_f(@target)
        end
        register_command(short_description, @command, options)
      end
    end

    # Register build results from a {Command} with the cache.
    #
    # @since 1.10.0
    #
    # @param options [Hash]
    #   Builder finalize options.
    # @option options [String] :stdout
    #   File name to redirect standard output to.
    #
    # @return [true]
    #   Return value for {#run} method.
    def finalize_command(options = {})
      sources = options[:sources] || @sources
      @cache.register_build(@target, @command, sources, @env)
      true
    end

    # A builder can indicate to Rscons that it needs to wait for a separate
    # operation to complete by using this method. The return value from this
    # method should be returned from the builder's #run method.
    #
    # @param things [Builder, Command, Thread, Array<Builder, Command, Thread>]
    #   Builder(s) or Command(s) or Thread(s) that this builder needs to wait
    #   for.
    def wait_for(things)
      Array(things)
    end

  end
end
