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

      class << self
        # Return a set of build features that this builder provides.
        #
        # @return [Array<String>]
        #   Set of build features that this builder provides.
        def features
          %w[shared]
        end
      end

      # Create an instance of the Builder to build a target.
      def initialize(options)
        super(options)
        libprefix = @env.expand_varref("${SHLIBPREFIX}", @vars)
        unless File.basename(@target).start_with?(libprefix)
          @target = @target.sub!(%r{^(.*/)?([^/]+)$}, "\\1#{libprefix}\\2")
        end
        unless File.basename(@target)["."]
          @target += @env.expand_varref("${SHLIBSUFFIX}", @vars)
        end
        suffixes = @env.expand_varref(["${OBJSUFFIX}", "${LIBSUFFIX}"], @vars)
        # Register builders to build each source to an object file or library.
        @objects = @env.register_builds(@target, @sources, suffixes, @vars,
                                        features: %w[shared])
      end

      # Run the builder to produce a build target.
      def run(options)
        if @command
          finalize_command(sources: @objects)
          true
        else
          ld = @env.expand_varref("${SHLD}", @vars)
          ld = if ld != ""
                 ld
               elsif @sources.find {|s| s.end_with?(*@env.expand_varref("${DSUFFIX}", @vars))}
                 "${SHDC}"
               elsif @sources.find {|s| s.end_with?(*@env.expand_varref("${CXXSUFFIX}", @vars))}
                 "${SHCXX}"
               else
                 "${SHCC}"
               end
          @vars["_TARGET"] = @target
          @vars["_SOURCES"] = @objects
          @vars["SHLD"] = ld
          command = @env.build_command("${SHLDCMD}", @vars)
          standard_command("SHLD #{@target}", command, sources: @objects)
        end
      end

    end
  end
end
