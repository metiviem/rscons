module Rscons
  module Builders
    # Execute a command that will produce the given target based on the given
    # sources.
    #
    # @since 1.8.0
    #
    # Example:
    #   env.Command("docs.html", "docs.md",
    #               CMD => %w[pandoc -fmarkdown -thtml -o${_TARGET} ${_SOURCES}])
    class Command < Builder

      # Run the builder to produce a build target.
      #
      # @param options [Hash] Builder run options.
      #
      # @return [String, ThreadedCommand]
      #   Target file name if target is up to date or a {ThreadedCommand}
      #   to execute to build the target.
      def run(options)
        target, sources, cache, env, vars = options.values_at(:target, :sources, :cache, :env, :vars)
        vars = vars.merge({
          "_TARGET" => target,
          "_SOURCES" => sources,
        })
        command = env.build_command("${CMD}", vars)
        cmd_desc = vars["CMD_DESC"] || "Command"
        options = {}
        if vars["CMD_STDOUT"]
          options[:stdout] = env.expand_varref("${CMD_STDOUT}", vars)
        end
        standard_threaded_build("#{cmd_desc} #{target}", target, command, sources, env, cache, options)
      end

      # Finalize a build.
      #
      # @param options [Hash]
      #   Finalize options.
      #
      # @return [String, nil]
      #   The target name on success or nil on failure.
      def finalize(options)
        standard_finalize(options)
      end

    end
  end
end
