module Rscons
  module Builders
    module Mixins
      module Object

        class << self
          # Hook called by Ruby when this module is included by a class (klass).
          def included(klass)
            klass.__send__(:extend, ClassMethods)
          end
        end

        # Object mixin class methods.
        module ClassMethods
          # @return [Array<Hash>]
          #   Parameters used to build.
          def providers
            @providers ||= []
          end

          # Register a set of parameters that can be used to build an Object.
          #
          # @param params [Hash]
          #   Build parameters.
          # @option params [Array, String] :command
          #   Command or construction variable reference thereto.
          # @option params [Array, String] :suffix
          #   Suffix(es) or construction variable reference thereto.
          # @option params [String] :short_description
          #   Short description to be printed when the builder runs (default:
          #   "Compiling")
          def register(params)
            providers << params
          end
        end

        # Construct a builder conforming to the Object interface.
        def initialize(params)
          super
          build_params = self.class.providers.find do |build_params|
            @sources.first.end_with?(*@env.expand_varref(build_params[:suffix], @vars))
          end
          unless build_params
            raise "Unknown input file type: #{@sources.first.inspect}"
          end
          @command_template = build_params[:command]
          @short_description = build_params[:short_description] || "Compiling"
        end

        # Run the builder to produce a build target.
        def run(params)
          if @command
            deps = @sources
            if File.exists?(@vars["_DEPFILE"])
              deps += Util.parse_makefile_deps(@vars["_DEPFILE"])
            end
            @cache.register_build(@target, @command, deps.uniq, @env)
            true
          else
            @vars["_TARGET"] = @target
            @vars["_SOURCES"] = @sources
            @vars["_DEPFILE"] = Rscons.set_suffix(target, env.expand_varref("${DEPFILESUFFIX}", vars))
            command = @env.build_command(@command_template, @vars)
            @env.produces(@target, @vars["_DEPFILE"])
            message = "#{@short_description} #{Util.short_format_paths(@sources)}"
            standard_command(message, command)
          end
        end

      end
    end
  end
end
