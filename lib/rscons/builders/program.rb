module Rscons
  module Builders
    # A default Rscons builder that knows how to link object files into an
    # executable program.
    class Program < Builder

      Rscons.application.default_varset.append(
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
      )

      # Create an instance of the Builder to build a target.
      #
      # @param options [Hash]
      #   Options.
      # @option options [String] :target
      #   Target file name.
      # @option options [Array<String>] :sources
      #   Source file name(s).
      # @option options [Environment] :env
      #   The Environment executing the builder.
      # @option options [Hash,VarSet] :vars
      #   Extra construction variables.
      def initialize(options)
        super(options)
        unless File.basename(@target)["."]
          @target += @env.expand_varref("${PROGSUFFIX}", @vars)
        end
        suffixes = @env.expand_varref(["${OBJSUFFIX}", "${LIBSUFFIX}"], @vars)
        # Register builders to build each source to an object file or library.
        @objects = @env.register_builds(@target, @sources, suffixes, @vars)
      end

      # Run the builder to produce a build target.
      def run(options)
        if @command
          finalize_command(sources: @objects)
          true
        else
          ld = @env.expand_varref("${LD}", @vars)
          ld = if ld != ""
                 ld
               elsif @sources.find {|s| s.end_with?(*@env.expand_varref("${DSUFFIX}", @vars))}
                 "${DC}"
               elsif @sources.find {|s| s.end_with?(*@env.expand_varref("${CXXSUFFIX}", @vars))}
                 "${CXX}"
               else
                 "${CC}"
               end
          @vars["_TARGET"] = @target
          @vars["_SOURCES"] = @objects
          @vars["LD"] = ld
          command = @env.build_command("${LDCMD}", @vars)
          standard_command("Linking => #{@target}", command, sources: @objects)
        end
      end

    end
  end
end
