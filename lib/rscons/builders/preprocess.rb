require "fileutils"

module Rscons
  module Builders
    # The Preprocess builder invokes the C preprocessor
    class Preprocess < Builder

      # Return default construction variables for the builder.
      #
      # @param env [Environment] The Environment using the builder.
      #
      # @return [Hash] Default construction variables for the builder.
      def default_variables(env)
        {
          "CPP_CMD" => %w[
            ${_PREPROCESS_CC} -E ${_PREPROCESS_DEPGEN}
            -o ${_TARGET} -I${CPPPATH} ${CPPFLAGS} ${_SOURCES}],
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
        if sources.find {|s| s.end_with?(*env.expand_varref("${CXXSUFFIX}", vars))}
          pp_cc = "${CXX}"
          depgen = "${CXXDEPGEN}"
        else
          pp_cc = "${CC}"
          depgen = "${CCDEPGEN}"
        end
        vars = vars.merge("_PREPROCESS_CC" => pp_cc,
                          "_PREPROCESS_DEPGEN" => depgen,
                          "_TARGET" => target,
                          "_SOURCES" => sources,
                          "_DEPFILE" => Rscons.set_suffix(target, env.expand_varref("${DEPFILESUFFIX}", vars)))
        command = env.build_command("${CPP_CMD}", vars)
        unless cache.up_to_date?(target, command, sources, env)
          cache.mkdir_p(File.dirname(target))
          return false unless env.execute("Preprocess #{target}", command)
          deps = sources
          if File.exists?(vars["_DEPFILE"])
            deps += Environment.parse_makefile_deps(vars["_DEPFILE"], nil)
            FileUtils.rm_f(vars["_DEPFILE"])
          end
          cache.register_build(target, command, deps.uniq, env)
        end
        target
      end

    end
  end
end
