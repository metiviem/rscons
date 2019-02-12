require "fileutils"

module Rscons
  module Builders
    # The Preprocess builder invokes the C preprocessor
    class Preprocess < Builder

      Rscons.application.default_varset.append(
        "CPP_CMD" => %w[
          ${_PREPROCESS_CC} -E ${_PREPROCESS_DEPGEN}
          -o ${_TARGET} ${INCPREFIX}${CPPPATH} ${CPPFLAGS} ${_SOURCES}],
      )

      # Run the builder to produce a build target.
      #
      # @param options [Hash] Builder run options.
      #
      # @return [String, ThreadedCommand]
      #   Target file name if target is up to date or a {ThreadedCommand}
      #   to execute to build the target.
      def run(options)
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
        # Store vars back into options so new keys are accessible in #finalize.
        options[:vars] = vars
        standard_threaded_build("#{name} #{@target}", @target, command, @sources, @env, @cache)
      end

      # Finalize the build operation.
      #
      # @param options [Hash] Builder finalize options.
      #
      # @return [String, nil]
      #   Name of the target file on success or nil on failure.
      def finalize(options)
        if options[:command_status]
          target, deps, cache, env, vars = options.values_at(:target, :sources, :cache, :env, :vars)
          if File.exists?(vars['_DEPFILE'])
            deps += Util.parse_makefile_deps(vars['_DEPFILE'])
          end
          cache.register_build(target, options[:tc].command, deps.uniq, env)
          target
        end
      end

    end
  end
end
