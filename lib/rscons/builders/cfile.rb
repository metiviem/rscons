module Rscons
  module Builders
    # Build a C or C++ source file given a lex (.l, .ll) or yacc (.y, .yy)
    # input file.
    #
    # Examples::
    #   env.CFile("parser.tab.cc", "parser.yy")
    #   env.CFile("lex.yy.cc", "parser.ll")
    class CFile < Builder

      Rscons.application.default_varset.append(
        "YACC" => "bison",
        "YACC_FLAGS" => ["-d"],
        "YACC_CMD" => ["${YACC}", "${YACC_FLAGS}", "-o", "${_TARGET}", "${_SOURCES}"],
        "YACCSUFFIX" => [".y", ".yy"],
        "LEX" => "flex",
        "LEX_FLAGS" => [],
        "LEX_CMD" => ["${LEX}", "${LEX_FLAGS}", "-o", "${_TARGET}", "${_SOURCES}"],
        "LEXSUFFIX" => [".l", ".ll"],
      )

      # Run the builder to produce a build target.
      def run(options)
        @vars["_TARGET"] = @target
        @vars["_SOURCES"] = @sources
        cmd =
          case
          when @sources.first.end_with?(*@env.expand_varref("${LEXSUFFIX}"))
            "LEX"
          when @sources.first.end_with?(*@env.expand_varref("${YACCSUFFIX}"))
            "YACC"
          else
            raise "Unknown source file #{@sources.first.inspect} for CFile builder"
          end
        command = @env.build_command("${#{cmd}_CMD}", @vars)
        standard_threaded_build("#{cmd} #{@target}", @target, command, @sources, @env, @cache)
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
