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
    # @param target [Symbol, String]
    #   Build target name.
    # @param builder [Builder]
    #   The {Builder} to use to build the target.
    # @param sources [Array<String>]
    #   Source file name(s).
    # @param vars [Hash]
    #   Construction variable overrides.
    def add_job(builder, target, sources, vars)
      # We allow multiple jobs to be registered per target for cases like:
      #   env.Directory("dest")
      #   env.Install("dest", "bin")
      #   env.Install("dest", "share")
      @jobs[target] ||= []
      @jobs[target] << {
        builder: builder,
        target: target,
        sources: sources,
        vars: vars,
      }
    end

    # Get the next job that is ready to run from the JobSet.
    #
    # This method will remove the job from the JobSet.
    #
    # @return [nil, Hash]
    #   The next job to run.
    def get_next_job_to_run
      if @jobs.size > 0
        evaluated_targets = Set.new
        attempt = lambda do |target|
          evaluated_targets << target
          @jobs[target][0][:sources].each do |src|
            if @jobs.include?(src) and not evaluated_targets.include?(src)
              return attempt[src]
            end
          end
          job = @jobs[target][0]
          if @jobs[target].size > 1
            @jobs[target].slice!(0)
          else
            @jobs.delete(target)
          end
          return job
        end
        attempt[@jobs.first.first]
      end
    end

    # Remove all jobs from the JobSet.
    def clear!
      @jobs.clear
    end

  end
end
