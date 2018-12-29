module Rscons
  module Builders
    # A default Rscons builder that produces a static library archive.
    class Library < Builder

      Rscons.application.default_varset.append(
        'AR' => 'ar',
        'LIBSUFFIX' => '.a',
        'ARFLAGS' => ['rcs'],
        'ARCMD' => ['${AR}', '${ARFLAGS}', '${_TARGET}', '${_SOURCES}']
      )

      # Set up a build operation using this builder.
      #
      # @param options [Hash] Builder setup options.
      #
      # @return [Object]
      #   Any object that the builder author wishes to be saved and passed back
      #   in to the {#run} method.
      def setup(options)
        target, sources, env, vars = options.values_at(:target, :sources, :env, :vars)
        suffixes = env.expand_varref(["${OBJSUFFIX}", "${LIBSUFFIX}"], vars)
        # Register builders to build each source to an object file or library.
        env.register_builds(target, sources, suffixes, vars)
      end

      # Run the builder to produce a build target.
      #
      # @param options [Hash] Builder run options.
      #
      # @return [String,false]
      #   Name of the target file on success or false on failure.
      def run(options)
        target, sources, cache, env, vars, objects = options.values_at(:target, :sources, :cache, :env, :vars, :setup_info)
        vars = vars.merge({
          '_TARGET' => target,
          '_SOURCES' => objects,
        })
        options[:sources] = objects
        command = env.build_command("${ARCMD}", vars)
        standard_threaded_build("AR #{target}", target, command, objects, env, cache)
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
