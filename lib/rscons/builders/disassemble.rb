module Rscons
  module Builders
    # The Disassemble builder produces a disassembly listing of a source file.
    class Disassemble < Builder

      Rscons.application.default_varset.append(
        "OBJDUMP" => "objdump",
        "DISASM_CMD" => ["${OBJDUMP}", "${DISASM_FLAGS}", "${_SOURCES}"],
        "DISASM_FLAGS" => ["--disassemble", "--source"],
      )

      # Run the builder to produce a build target.
      def run(options)
        @vars["_SOURCES"] = sources
        command = @env.build_command("${DISASM_CMD}", @vars)
        if @cache.up_to_date?(@target, command, @sources, @env)
          @target
        else
          @cache.mkdir_p(File.dirname(@target))
          ThreadedCommand.new(
            command,
            short_description: "Disassemble #{@target}",
            system_options: {out: @target})
        end
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
