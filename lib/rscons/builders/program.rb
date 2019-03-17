module Rscons
  module Builders
    # A default Rscons builder that knows how to link object files into an
    # executable program.
    class Program < Builder

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
        @objects = @sources.map do |source|
          if source.end_with?(*suffixes)
            source
          else
            @env.register_dependency_build(@target, source, suffixes.first, @vars, Object)
          end
        end
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
