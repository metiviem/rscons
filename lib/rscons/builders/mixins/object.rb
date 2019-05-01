module Rscons
  class Builder
    # @return [String, nil]
    #   Preferred linker for this object file, or a construction variable
    #   reference thereto.
    attr_reader :preferred_ld
  end

  module Builders
    module Mixins
      module Object

        include Depfile

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
          # @option params [String] :preferred_ld
          #   Preferred linker for this object file, or a construction variable
          #   reference thereto.
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
          @command_template =
            if @vars[:direct]
              build_params[:direct_command]
            else
              build_params[:command]
            end
          @short_description = build_params[:short_description] || "Compiling"
          @preferred_ld = build_params[:preferred_ld]
        end

        # Run the builder to produce a build target.
        def run(params)
          if @command
            finalize_command_with_depfile
          else
            @vars["_TARGET"] = @target
            @vars["_SOURCES"] = @sources
            depfilesuffix = @env.expand_varref("${DEPFILESUFFIX}", vars)
            @vars["_DEPFILE"] =
              if @vars[:direct]
                @env.get_build_fname(target, depfilesuffix, self.class)
              else
                Rscons.set_suffix(target, depfilesuffix)
              end
            @cache.mkdir_p(File.dirname(@vars["_DEPFILE"]))
            command = @env.build_command(@command_template, @vars)
            @env.produces(@target, @vars["_DEPFILE"])
            if @vars[:direct]
              message = "#{@short_description}/Linking <source>#{Util.short_format_paths(@sources)}<reset> => <target>#{@target}<reset>"
            else
              message = "#{@short_description} <source>#{Util.short_format_paths(@sources)}<reset>"
            end
            standard_command(message, command)
          end
        end

      end
    end
  end
end
