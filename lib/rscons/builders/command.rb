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
      # @param target [String] Target file name.
      # @param sources [Array<String>] Source file name(s).
      # @param cache [Cache] The Cache object.
      # @param env [Environment] The Environment executing the builder.
      # @param vars [Hash,VarSet] Extra construction variables.
      #
      # @return [String,false]
      #   Name of the target file on success or false on failure.
      def run(target, sources, cache, env, vars)
        vars = vars.merge({
          "_TARGET" => target,
          "_SOURCES" => sources,
        })
        command = env.build_command("${CMD}", vars)
        cmd_desc = vars["CMD_DESC"] || "cmd_desc"
        standard_build("#{cmd_desc} #{target}", target, command, sources, env, cache)
      end
    end
  end
end
