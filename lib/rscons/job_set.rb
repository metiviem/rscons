require "set"

module Rscons
  # Class to keep track of a set of jobs that need to be performed.
  class JobSet

    # Create a JobSet
    #
    # @param build_dependencies [Hash]
    #   Hash mapping targets to a set of build dependencies. A job will not be
    #   returned as ready to run if any of its dependencies are still building.
    def initialize(build_dependencies)
      @jobs = {}
      @build_dependencies = build_dependencies
    end

    # Add a job to the JobSet.
    #
    # @param options [Hash]
    #   Options.
    # @option options [Symbol, String] :target
    #   Build target name.
    # @option options [Builder] :builder
    #   The {Builder} to use to build the target.
    # @option options [Array<String>] :sources
    #   Source file name(s).
    # @option options [Hash] :vars
    #   Construction variable overrides.
    def add_job(options)
      # We allow multiple jobs to be registered per target for cases like:
      #   env.Directory("dest")
      #   env.Install("dest", "bin")
      #   env.Install("dest", "share")
      @jobs[options[:target]] ||= []
      @jobs[options[:target]] << options
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
      @jobs.keys.each do |target|
        skip = false
        (@jobs[target][0][:sources] + (@build_dependencies[target] || []).to_a).each do |src|
          if @jobs.include?(src)
            # Skip this target because it depends on another target not yet
            # built.
            skip = true
            break
          end
          if targets_still_building.include?(src)
            # Skip this target because it depends on another target that is
            # currently being built.
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
