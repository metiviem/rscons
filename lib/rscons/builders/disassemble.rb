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
        if @command
          finalize_command
        else
          @vars["_SOURCES"] = @sources
          command = @env.build_command("${DISASM_CMD}", @vars)
          standard_command("Disassemble #{target}", command, stdout: @target)
        end
      end

    end
  end
end
