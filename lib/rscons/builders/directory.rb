module Rscons
  module Builders
    # The Directory builder creates a directory.
    class Directory < Builder

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
        if File.directory?(target)
          target
        elsif File.exist?(target)
          Ansi.write($stderr, :red, "Error: `#{target}' already exists and is not a directory", :reset, "\n")
          false
        else
          env.print_builder_run_message("Directory #{target}", nil)
          cache.mkdir_p(target)
          target
        end
      end

    end
  end
end
