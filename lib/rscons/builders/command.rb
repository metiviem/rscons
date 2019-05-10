module Rscons
  module Builders
    # A builder to execute an arbitrary command that will produce the given
    # target based on the given sources.
    #
    # Example:
    #   env.Command("docs.html", "docs.md",
    #               CMD => %w[pandoc -fmarkdown -thtml -o${_TARGET} ${_SOURCES}])
    class Command < Builder

      # Run the builder to produce a build target.
      def run(options)
        if @command
          finalize_command
        else
          @vars["_TARGET"] = @target
          @vars["_SOURCES"] = @sources
          command = @env.build_command("${CMD}", @vars)
          cmd_desc = @vars["CMD_DESC"] || "Command"
          options = {}
          if @vars["CMD_STDOUT"]
            options[:stdout] = @env.expand_varref("${CMD_STDOUT}", @vars)
          end
          standard_command("#{cmd_desc} <target>#{@target}<reset>", command, options)
        end
      end

    end
  end
end
