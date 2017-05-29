module Rscons
  module Builders
    # Build a C or C++ source file given a lex (.l, .ll) or yacc (.y, .yy)
    # input file.
    #
    # Examples::
    #   env.CFile("parser.tab.cc", "parser.yy")
    #   env.CFile("lex.yy.cc", "parser.ll")
    class CFile < Builder

      # Return default construction variables for the builder.
      #
      # @param env [Environment] The Environment using the builder.
      #
      # @return [Hash] Default construction variables for the builder.
      def default_variables(env)
        {
          "YACC" => "bison",
          "YACC_FLAGS" => ["-d"],
          "YACC_CMD" => ["${YACC}", "${YACC_FLAGS}", "-o", "${_TARGET}", "${_SOURCES}"],
          "YACCSUFFIX" => [".y", ".yy"],
          "LEX" => "flex",
          "LEX_FLAGS" => [],
          "LEX_CMD" => ["${LEX}", "${LEX_FLAGS}", "-o", "${_TARGET}", "${_SOURCES}"],
          "LEXSUFFIX" => [".l", ".ll"],
        }
      end

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
        cmd =
          case
          when sources.first.end_with?(*env.expand_varref("${LEXSUFFIX}"))
            "LEX"
          when sources.first.end_with?(*env.expand_varref("${YACCSUFFIX}"))
            "YACC"
          else
            raise "Unknown source file #{sources.first.inspect} for CFile builder"
          end
        command = env.build_command("${#{cmd}_CMD}", vars)
        standard_threaded_build("#{cmd} #{target}", target, command, sources, env, cache)
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
