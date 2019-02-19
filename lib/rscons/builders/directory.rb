module Rscons
  module Builders
    # The Directory builder creates a directory.
    class Directory < Builder

      # Run the builder to produce a build target.
      def run(options)
        if File.directory?(@target)
          true
        elsif File.exists?(@target)
          Ansi.write($stderr, :red, "Error: `#{@target}' already exists and is not a directory", :reset, "\n")
          false
        else
          print_run_message("Creating directory => #{@target}", nil)
          @cache.mkdir_p(@target)
          true
        end
      end

    end
  end
end
