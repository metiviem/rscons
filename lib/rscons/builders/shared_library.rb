module Rscons
  module Builders
    # A default Rscons builder that knows how to link object files into a
    # shared library.
    class SharedLibrary < Builder

      Rscons.application.default_varset.append(
        'SHLIBPREFIX' => (RUBY_PLATFORM =~ /mingw/ ? '' : 'lib'),
        'SHLIBSUFFIX' => (RUBY_PLATFORM =~ /mingw/ ? '.dll' : '.so'),
        'SHLDFLAGS' => ['${LDFLAGS}', '-shared'],
        'SHLD' => nil,
        'SHLIBDIRPREFIX' => '-L',
        'SHLIBLINKPREFIX' => '-l',
        'SHLDCMD' => ['${SHLD}', '-o', '${_TARGET}', '${SHLDFLAGS}', '${_SOURCES}', '${SHLIBDIRPREFIX}${LIBPATH}', '${SHLIBLINKPREFIX}${LIBS}']
      )

      # Return a set of build features that this builder provides.
      #
      # @return [Array<String>]
      #   Set of build features that this builder provides.
      def features
        %w[shared]
      end

      # Create a BuildTarget object for this build target.
      #
      # The build target filename is given a platform-dependent suffix if no
      # other suffix is given.
      #
      # @param options [Hash]
      #   Options to create the BuildTarget with.
      # @option options [Environment] :env
      #   The Environment.
      # @option options [String] :target
      #   The user-supplied target name.
      # @option options [Array<String>] :sources
      #   The user-supplied source file name(s).
      #
      # @return [BuildTarget]
      def create_build_target(options)
        env, target, vars = options.values_at(:env, :target, :vars)
        my_options = options.dup
        libprefix = env.expand_varref("${SHLIBPREFIX}", vars)
        unless File.basename(target).start_with?(libprefix)
          my_options[:target].sub!(%r{^(.*/)?([^/]+)$}, "\\1#{libprefix}\\2")
        end
        unless File.basename(target)["."]
          my_options[:target] += env.expand_varref("${SHLIBSUFFIX}", vars)
        end
        super(my_options)
      end

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
        env.register_builds(target, sources, suffixes, vars,
                            features: %w[shared])
      end

      # Run the builder to produce a build target.
      #
      # @param options [Hash] Builder run options.
      #
      # @return [String,false]
      #   Name of the target file on success or false on failure.
      def run(options)
        target, sources, cache, env, vars, objects = options.values_at(:target, :sources, :cache, :env, :vars, :setup_info)
        ld = env.expand_varref("${SHLD}", vars)
        ld = if ld != ""
               ld
             elsif sources.find {|s| s.end_with?(*env.expand_varref("${DSUFFIX}", vars))}
               "${SHDC}"
             elsif sources.find {|s| s.end_with?(*env.expand_varref("${CXXSUFFIX}", vars))}
               "${SHCXX}"
             else
               "${SHCC}"
             end
        vars = vars.merge({
          '_TARGET' => target,
          '_SOURCES' => objects,
          'SHLD' => ld,
        })
        options[:sources] = objects
        command = env.build_command("${SHLDCMD}", vars)
        standard_threaded_build("SHLD #{target}", target, command, objects, env, cache)
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
