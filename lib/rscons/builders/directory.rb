module Rscons
  module Builders
    # The Directory builder creates a directory.
    class Directory < Builder

      # Run the builder to produce a build target.
      def run(options)
        target, sources, cache, env, vars = options.values_at(:target, :sources, :cache, :env, :vars)
        if File.directory?(target)
          target
        elsif File.exists?(target)
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
