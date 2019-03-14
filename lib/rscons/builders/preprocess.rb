require "fileutils"

module Rscons
  module Builders
    # The Preprocess builder invokes the C preprocessor
    class Preprocess < Builder

      # Run the builder to produce a build target.
      def run(options)
        if @command
          deps = @sources
          if File.exists?(@vars["_DEPFILE"])
            deps += Util.parse_makefile_deps(@vars["_DEPFILE"])
          end
          @cache.register_build(@target, @command, deps.uniq, @env)
          true
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
          @env.produces(@target, @vars["_DEPFILE"])
          standard_command("Preprocessing #{Util.short_format_paths(@sources)} => #{@target}", command)
        end
      end

    end
  end
end
