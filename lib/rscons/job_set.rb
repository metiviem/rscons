require "set"

module Rscons
  # Class to keep track of a set of jobs that need to be performed.
  class JobSet

    # Create a JobSet
    #
    # @param build_dependencies [Hash]
    #   Hash mapping targets to a set of build dependencies. A job will not be
    #   returned as ready to run if any of its dependencies are still building.
    # @param side_effects [Hash]
    #   Hash mapping targets to a set of side-effect files. A job will not be
    #   returned as ready to run if any of its dependencies is a side-effect
    #   of another target that has not yet been built.
    def initialize(build_dependencies, side_effects)
      @jobs = {}
      @build_dependencies = build_dependencies
      @side_effects = side_effects
    end

    # Add a job to the JobSet.
    #
    # @param builder [Builder]
    #   The {Builder} that will produce the target.
    def add_job(builder)
      # We allow multiple jobs to be registered per target for cases like:
      #   env.Directory("dest")
      #   env.Install("dest", "bin")
      #   env.Install("dest", "share")
      @jobs[builder.target] ||= []
      @jobs[builder.target] << builder
    end

    # Get the next job that is ready to run from the JobSet.
    #
    # This method will remove the job from the JobSet.
    #
    # @param targets_still_building [Array<String>]
    #   Targets that are not finished building. This is used to avoid returning
    #   a job as available to run if it depends on one of the targets that are
    #   still building as a source.
    #
    # @return [nil, Hash]
    #   The next job to run.
    def get_next_job_to_run(targets_still_building)
      targets_not_built_yet = targets_still_building + @jobs.keys
      side_effects = targets_not_built_yet.map do |target|
        @side_effects[target] || []
      end.flatten
      targets_not_built_yet += side_effects

      @jobs.keys.each do |target|
        skip = false
        (@jobs[target][0].sources + (@build_dependencies[target] || []).to_a).each do |src|
          if targets_not_built_yet.include?(src)
            skip = true
            break
          end
        end
        next if skip
        job = @jobs[target][0]
        if @jobs[target].size > 1
          @jobs[target].slice!(0)
        else
          @jobs.delete(target)
        end
        return job
      end

      # If there is a job to run, and nothing is still building, but we did
      # not find a job to run above, then there might be a circular dependency
      # introduced by the user.
      if (@jobs.size > 0) and targets_still_building.empty?
        raise "Could not find a runnable job. Possible circular dependency for #{@jobs.keys.first}"
      end
    end

    # Remove all jobs from the JobSet.
    def clear!
      @jobs.clear
    end

    # Get the JobSet size.
    #
    # @return [Integer]
    #   JobSet size.
    def size
      @jobs.size
    end

  end
end
