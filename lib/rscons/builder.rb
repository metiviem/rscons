require "fileutils"

module Rscons
  # Namespace module in which to store builders for convenient grouping
  module Builders; end

  # Class to hold an object that knows how to build a certain type of file.
  class Builder
    # Return the name of the builder.
    #
    # If not overridden this defaults to the last component of the class name.
    #
    # @return [String] The name of the builder.
    def name
      self.class.name.split(":").last
    end

    # Return a set of default construction variables for the builder.
    #
    # @param env [Environment] The Environment.
    #
    # @return [Hash] Default construction variables.
    def default_variables(env)
      {}
    end

    # Create a BuildTarget object for this build target.
    #
    # Builder sub-classes can override this method to manipulate parameters
    # (for example, add a suffix to the user-given target file name).
    #
    # @param options [Hash] Options to create the BuildTarget with.
    # @option options [Environment] :env
    #   The Environment.
    # @option options [String] :target
    #   The user-supplied target name.
    # @option options [Array<String>] :sources
    #   The user-supplied source file name(s).
    #
    # @return [BuildTarget]
    def create_build_target(options)
      BuildTarget.new(options)
    end

    # Return whether this builder object is capable of producing a given target
    # file name from a given source file name.
    #
    # @param target [String] The target file name.
    # @param source [String] The source file name.
    # @param env [Environment] The Environment.
    #
    # @return [Boolean]
    #   Whether this builder object is capable of producing a given target
    #   file name from a given source file name.
    def produces?(target, source, env)
      false
    end

    # Set up a build operation using this builder.
    #
    # This method is called when a build target is registered using this
    # builder. This method should not do any building, but should perform any
    # setup needed and register any prerequisite build targets that need to be
    # built before the target being requested here.
    #
    # If the builder needs no special setup, it does not need to override this
    # method. If there is any information produced in this method that will be
    # needed later in the build, it can be stored in the return value from this
    # method, which will be passed to the {#run} method.
    #
    # @since 1.10.0
    #
    # @param options [Hash]
    #   Options.
    # @option options [String] :target
    #   Target file name.
    # @option options [Array<String>] :sources
    #   Source file name(s).
    # @option options [Environment] :env
    #   The Environment executing the builder.
    # @option options [Hash,VarSet] :vars
    #   Extra construction variables.
    #
    # @return [Object]
    #   Any object that the builder author wishes to be saved and passed back
    #   in to the {#run} method.
    def setup(options)
    end

    # Run the builder to produce a build target.
    #
    # The run method supports two different signatures - an older signature
    # with five separate arguments, and a newer one with one Hash argument. A
    # builder author can use either signature, and Rscons will automatically
    # determine which arguments to pass when invoking the run method based on
    # the method's arity.
    #
    # @overload run(target, sources, cache, env, vars)
    #
    #   @param target [String]
    #     Target file name.
    #   @param sources [Array<String>]
    #     Source file name(s).
    #   @param cache [Cache]
    #     The Cache object.
    #   @param env [Environment]
    #     The Environment executing the builder.
    #   @param vars [Hash,VarSet]
    #     Extra construction variables.
    #
    # @overload run(options)
    #
    #   @since 1.10.0
    #
    #   @param options [Hash] Run options.
    #   @option options [String] :target
    #     Target file name.
    #   @option options [Array<String>] :sources
    #     Source file name(s).
    #   @option options [Cache] :cache
    #     The Cache object.
    #   @option options [Environment] :env
    #     The Environment executing the builder.
    #   @option options [Hash,VarSet] :vars
    #     Extra construction variables.
    #   @option options [Object] :setup_info
    #     Whatever value was returned from this builder's {#setup} method call.
    #
    # @return [String,false]
    #   Name of the target file on success or false on failure.
    def run(options)
      raise "This method must be overridden in a subclass"
    end

    # Check if the cache is up to date for the target and if not execute the
    # build command.
    #
    # @param short_cmd_string [String]
    #   Short description of build action to be printed when env.echo ==
    #   :short.
    # @param target [String] Name of the target file.
    # @param command [Array<String>]
    #   The command to execute to build the target.
    # @param sources [Array<String>] Source file name(s).
    # @param env [Environment] The Environment executing the builder.
    # @param cache [Cache] The Cache object.
    #
    # @return [String,false]
    #   The name of the target on success or false on failure.
    def standard_build(short_cmd_string, target, command, sources, env, cache)
      unless cache.up_to_date?(target, command, sources, env)
        unless Rscons.phony_target?(target)
          cache.mkdir_p(File.dirname(target))
          FileUtils.rm_f(target)
        end
        return false unless env.execute(short_cmd_string, command)
        cache.register_build(target, command, sources, env)
      end
      target
    end
  end
end
