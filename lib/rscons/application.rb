require "set"

module Rscons

  # Functionality for an instance of the rscons application invocation.
  class Application

    # @return [String]
    #   Top-level build directory.
    attr_accessor :build_dir

    # @return [Boolean]
    #   Whether to output ANSI color escape sequences.
    attr_accessor :do_ansi_color

    # @return [Integer]
    #   The number of threads to use when scheduling subprocesses.
    attr_accessor :n_threads

    # @return [Boolean]
    #   Whether to run verbosely.
    attr_accessor :verbose

    # @return [VarSet]
    #   Access any variables set on the rscons command-line.
    attr_reader :vars

    # Create Application instance.
    def initialize
      @build_dir = "build"
      @n_threads = Util.determine_n_threads
      @vars = VarSet.new
      @operations = Set.new
      @build_step = 0
    end

    # Check whether a requested operation is active.
    #
    # @param op [String]
    #   Operation name.
    #
    # @return [Boolean]
    #   Whether the requested operation is active.
    def operation(op)
      @operations.include?(op)
    end

    # Run the specified operation.
    #
    # @param operation [String]
    #   The operation to perform (e.g. "clean", "configure", "build", etc...)
    # @param script [Script]
    #   The script.
    # @param operation_options [Hash]
    #   Option values from the CLI for the operation.
    # @param options [Hash]
    #   Optional parameters.
    # @option sub_op [Boolean]
    #   Whether this operation is not the top-level operation.
    #
    # @return [Integer]
    #   Process exit code (0 on success).
    def run(operation, script, operation_options, options = {})
      @start_time = Time.new
      @script = script
      @operations << operation
      puts "Starting '#{operation}' at #{Time.new}" if verbose
      rv =
        case operation
        when "build"
          rv = 0
          unless Cache.instance["configuration_data"]["configured"]
            rv =
              if @script.autoconf
                run("configure", script, operation_options, sub_op: false)
              else
                $stderr.puts "Project must be configured first, and autoconf is disabled"
                1
              end
          end
          if rv == 0
            build(operation_options)
          else
            rv
          end
        when "clean"
          clean
        when "configure"
          configure(operation_options)
        when "distclean"
          distclean
        when "install"
          run("build", script, operation_options, sub_op: false)
        when "uninstall"
          uninstall
        else
          $stderr.puts "Unknown operation: #{operation}"
          1
        end
      if verbose and options[:sub_op].nil?
        time = Time.new
        elapsed = time - @start_time
        puts "'#{operation}' complete at #{time} (#{Util.format_elapsed_time(elapsed)})"
      end
      rv
    end

    # Get the next build step number.
    #
    # This is used internally by the {Environment} class.
    #
    # @api private
    def get_next_build_step
      @build_step += 1
    end

    # Get the total number of build steps.
    #
    # @return [Integer]
    #   The total number of build steps.
    def get_total_build_steps
      Environment.environments.reduce(@build_step) do |result, env|
        result + env.build_steps_remaining
      end
    end

    private

    # Build the project.
    #
    # @param options [Hash]
    #   Options.
    #
    # @return [Integer]
    #   Exit code.
    def build(options)
      begin
        Cache.instance["failed_commands"] = []
        @script.build
        Environment.environments.each do |env|
          env.process
        end
        0
      rescue RsconsError => e
        Ansi.write($stderr, :red, e.message, :reset, "\n")
        1
      end
    end

    # Remove all generated files.
    #
    # @return [Integer]
    #   Exit code.
    def clean
      cache = Cache.instance
      # remove all built files
      cache.targets(false).each do |target|
        cache.remove_target(target)
        FileUtils.rm_f(target)
      end
      # remove all created directories if they are empty
      cache.directories(false).sort {|a, b| b.size <=> a.size}.each do |directory|
        cache.remove_directory(directory)
        next unless File.directory?(directory)
        if (Dir.entries(directory) - ['.', '..']).empty?
          Dir.rmdir(directory) rescue nil
        end
      end
      cache.write
      0
    end

    # Remove the build directory and clear the cache.
    #
    # @return [Integer]
    #   Exit code.
    def distclean
      cache = Cache.instance
      clean
      FileUtils.rm_rf(@build_dir)
      cache.clear
      0
    end

    # Configure the project.
    #
    # @param options [Hash]
    #   Options.
    #
    # @return [Integer]
    #   Exit code.
    def configure(options)
      rv = 0
      options = options.merge(project_name: @script.project_name)
      co = ConfigureOp.new(options)
      begin
        @script.configure(co)
      rescue RsconsError => e
        if e.message and e.message != ""
          $stderr.puts e.message
        end
        Ansi.write($stderr, :red, "Configuration failed", :reset, "\n")
        rv = 1
      end
      co.close(rv == 0)
      rv
    end

    # Remove installed files.
    #
    # @return [Integer]
    #   Exit code.
    def uninstall
      cache = Cache.instance
      cache.targets(true).each do |target|
        cache.remove_target(target)
        next unless File.exists?(target)
        puts "Removing #{target}" if verbose
        FileUtils.rm_f(target)
      end
      # remove all created directories if they are empty
      cache.directories(true).sort {|a, b| b.size <=> a.size}.each do |directory|
        cache.remove_directory(directory)
        next unless File.directory?(directory)
        if (Dir.entries(directory) - ['.', '..']).empty?
          puts "Removing #{directory}" if verbose
          Dir.rmdir(directory) rescue nil
        end
      end
      cache.write
      0
    end

  end

end
