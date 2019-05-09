require "fileutils"

module Rscons
  module Builders
    # The Preprocess builder invokes the C preprocessor
    class Preprocess < Builder

      include Mixins::Depfile

      # Run the builder to produce a build target.
      def run(options)
        if @command
          finalize_command_with_depfile
        else
          if @sources.find {|s| s.end_with?(*@env.expand_varref("${CXXSUFFIX}", @vars))}
            pp_cc = "${CXX}"
            depgen = "${CXXDEPGEN}"
          else
            pp_cc = "${CC}"
            depgen = "${CCDEPGEN}"
          end
          @vars["_PREPROCESS_CC"] = pp_cc
          @vars["_PREPROCESS_DEPGEN"] = depgen
          @vars["_TARGET"] = @target
          @vars["_SOURCES"] = @sources
          @vars["_DEPFILE"] = Rscons.set_suffix(target, env.expand_varref("${DEPFILESUFFIX}", vars))
          command = @env.build_command("${CPP_CMD}", @vars)
          self.produces(@vars["_DEPFILE"])
          standard_command("Preprocessing <source>#{Util.short_format_paths(@sources)}<reset> => <target>#{@target}<reset>", command)
        end
      end

    end
  end
end
