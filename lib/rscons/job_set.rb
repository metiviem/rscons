require "set"

module Rscons
  # Class to keep track of a set of jobs that need to be performed.
  class JobSet

    # Create a JobSet
    def initialize
      @jobs = {}
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
      attempted_targets = Set.new

      @jobs.keys.each do |target|
        attempted_targets << target
        skip = false
        @jobs[target][0][:sources].each do |src|
          if @jobs.include?(src) and not attempted_targets.include?(src)
            # Skip this target because it depends on another target later in
            # the job set.
            skip = true
            break
          end
          if targets_still_building.include?(src)
            # Skip this target because it depends on another target that is
            # still being built.
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

      nil
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
