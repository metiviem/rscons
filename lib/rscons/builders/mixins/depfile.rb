module Rscons
  module Builders
    module Mixins
      # Mixin for builders that make use of generated dependency files.
      module Depfile

        # Finalize a build operation including dependencies from a generated
        # dependency file.
        def finalize_command_with_depfile
          deps = @sources
          if File.exists?(@vars["_DEPFILE"])
            deps += Util.parse_dependency_file(@vars["_DEPFILE"])
          end
          @cache.register_build(@target, @command, deps.uniq, @env)
          true
        end

      end
    end
  end
end
