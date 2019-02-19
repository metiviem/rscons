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
        if @command
          finalize_command
        else
          @vars["_TARGET"] = @target
          @vars["_SOURCES"] = @sources
          case
          when @sources.first.end_with?(*@env.expand_varref("${LEXSUFFIX}"))
            cmd = "LEX"
            message = "Generating lexer"
          when @sources.first.end_with?(*@env.expand_varref("${YACCSUFFIX}"))
            cmd = "YACC"
            message = "Generating parser"
          else
            raise "Unknown source file #{@sources.first.inspect} for CFile builder"
          end
          command = @env.build_command("${#{cmd}_CMD}", @vars)
          standard_command("#{message} from #{Util.short_format_paths(@sources)} => #{@target}", command)
        end
      end

    end
  end
end
