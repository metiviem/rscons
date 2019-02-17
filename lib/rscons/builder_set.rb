module Rscons
  # Class to keep track of a set of builders to be executed.
  class BuilderSet < Hash

    # Create a BuilderSet.
    #
    # @param build_dependencies [Hash]
    #   Hash mapping targets to a set of build dependencies. A builder will not
    #   be returned as ready to run if any of its dependencies are still
    #   building.
    # @param side_effects [Hash]
    #   Hash mapping targets to a set of side-effect files. A builder will not
    #   be returned as ready to run if any of its dependencies is a side-effect
    #   of another target that has not yet been built.
    def initialize(build_dependencies, side_effects)
      super()
      @build_dependencies = build_dependencies
      @side_effects = side_effects
    end

    # Add a builder to the BuilderSet.
    #
    # @param builder [Builder]
    #   The {Builder} that will produce the target.
    def <<(builder)
      # We allow multiple builders to be registered per target for cases like:
      #   env.Directory("dest")
      #   env.Install("dest", "bin")
      #   env.Install("dest", "share")
      self[builder.target] ||= []
      self[builder.target] << builder
    end

    # Get the next builder that is ready to run from the BuilderSet.
    #
    # This method will remove the builder from the BuilderSet.
    #
    # @param targets_still_building [Array<String>]
    #   Targets that are not finished building. This is used to avoid returning
    #   a builder as available to run if it depends on one of the targets that
    #   are still building as a source.
    #
    # @return [nil, Builder]
    #   The next builder to run.
    def get_next_builder_to_run(targets_still_building)
      not_built_yet = targets_still_building + self.keys
      not_built_yet += not_built_yet.reduce([]) do |result, target|
        result + (@side_effects[target] || [])
      end

      target_to_build = self.keys.find do |target|
        deps = self[target][0].sources + (@build_dependencies[target] || []).to_a
        !deps.find {|dep| not_built_yet.include?(dep)}
      end

      if target_to_build
        builder = self[target_to_build][0]
        if self[target_to_build].size > 1
          self[target_to_build].slice!(0)
        else
          self.delete(target_to_build)
        end
        return builder
      end

      # If there is a builder to run, and nothing is still building, but we did
      # not find a builder to run above, then there might be a circular
      # dependency introduced by the user.
      if (self.size > 0) and targets_still_building.empty?
        raise "Could not find a runnable builder. Possible circular dependency for #{self.keys.first}"
      end
    end

  end
end
