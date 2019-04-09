module Rscons
  module Builders
    module Mixins
      # Mixin providing functionality for a builder that links object files
      # together into a program.
      module Program

        # Run the builder to produce a build target.
        def run(options)
          if @command
            finalize_command(sources: @objects)
          else
            ld = @env.expand_varref("${#{ld_var}}", @vars)
            if ld == ""
              @objects.find do |object|
                if builder = @env.builder_for(object)
                  if ld = builder.preferred_ld
                    true
                  end
                end
              end
            end
            if ld.nil? || ld == ""
              ld = default_ld
            end
            @vars["_TARGET"] = @target
            @vars["_SOURCES"] = @objects
            @vars["#{ld_var}"] = ld
            command = @env.build_command("${#{ld_var}CMD}", @vars)
            standard_command("Linking => #{@target}", command, sources: @objects)
          end
        end

      end
    end
  end
end
