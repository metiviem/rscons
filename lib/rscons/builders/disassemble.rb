module Rscons
  module Builders
    # The Disassemble builder produces a disassembly listing of a source file.
    class Disassemble < Builder

      # Run the builder to produce a build target.
      def run(options)
        if @command
          finalize_command
        else
          @vars["_SOURCES"] = @sources
          command = @env.build_command("${DISASM_CMD}", @vars)
          standard_command("Disassembling <source>#{Util.short_format_paths(@sources)}<reset> => <target>#{target}<reset>", command, stdout: @target)
        end
      end

    end
  end
end
