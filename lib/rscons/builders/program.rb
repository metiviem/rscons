module Rscons
  module Builders
    # A default Rscons builder that knows how to link object files into an
    # executable program.
    class Program < Builder

      # Return default construction variables for the builder.
      #
      # @param env [Environment] The Environment using the builder.
      #
      # @return [Hash] Default construction variables for the builder.
      def default_variables(env)
        {
          'OBJSUFFIX' => '.o',
          'PROGSUFFIX' => (Object.const_get("RUBY_PLATFORM") =~ /mingw|cygwin/ ? ".exe" : ""),
          'LD' => nil,
          'LIBSUFFIX' => '.a',
          'LDFLAGS' => [],
          'LIBPATH' => [],
          'LIBDIRPREFIX' => '-L',
          'LIBLINKPREFIX' => '-l',
          'LIBS' => [],
          'LDCMD' => ['${LD}', '-o', '${_TARGET}', '${LDFLAGS}', '${_SOURCES}', '${LIBDIRPREFIX}${LIBPATH}', '${LIBLINKPREFIX}${LIBS}']
        }
      end

      # Create a BuildTarget object for this build target.
      #
      # The build target filename is given a ".exe" suffix if Rscons is
      # executing on a Windows platform and no other suffix is given.
      #
      # @param options [Hash] Options to create the BuildTarget with.
      # @option options [Environment] :env
      #   The Environment.
      # @option options [String] :target
      #   The user-supplied target name.
      # @option options [Array<String>] :sources
      #   The user-supplied source file name(s).
      #
      # @return [BuildTarget]
      def create_build_target(options)
        my_options = options.dup
        unless my_options[:target] =~ /\./
          my_options[:target] += options[:env].expand_varref("${PROGSUFFIX}")
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
        ld = env.expand_varref("${LD}", vars)
        ld = if ld != ""
               ld
             elsif sources.find {|s| s.end_with?(*env.expand_varref("${DSUFFIX}", vars))}
               "${DC}"
             elsif sources.find {|s| s.end_with?(*env.expand_varref("${CXXSUFFIX}", vars))}
               "${CXX}"
             else
               "${CC}"
             end
        vars = vars.merge({
          '_TARGET' => target,
          '_SOURCES' => objects,
          'LD' => ld,
        })
        command = env.build_command("${LDCMD}", vars)
        standard_build("LD #{target}", target, command, objects, env, cache)
      end

    end
  end
end
