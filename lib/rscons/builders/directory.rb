module Rscons
  module Builders

    # The Directory builder creates a directory.
    class Directory < Builder

      # Run the builder to produce a build target.
      def run(options)
        install_builder = self.class.name == "InstallDirectory"
        if (not install_builder) or Rscons.application.operation("install")
          if File.directory?(@target)
            true
          elsif File.exists?(@target)
            Ansi.write($stderr, :red, "Error: `#{@target}' already exists and is not a directory", :reset, "\n")
            false
          else
            print_run_message("Creating directory => #{@target}", nil)
            @cache.mkdir_p(@target, install: install_builder)
            true
          end
        else
          true
        end
      end

    end

    # The InstallDirectory class is identical to Directory but only performs
    # an action for an "install" operation.
    class InstallDirectory < Directory; end

  end
end
