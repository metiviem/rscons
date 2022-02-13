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

    # @return [Script]
    #   Build script.
    attr_reader :script

    # @return [Boolean]
    #   Whether to configure silently.
    attr_accessor :silent_configure

    # @return [Boolean]
    #   Whether to run verbosely.
    attr_accessor :verbose

    # Create Application instance.
    def _initialize
      @script = Script.new
      @silent_configure = true
      @build_dir = ENV["RSCONS_BUILD_DIR"] || "build"
      ENV.delete("RSCONS_BUILD_DIR")
      @n_threads = Util.determine_n_threads
    end

    # Run the application.
    #
    # Execute user-specified tasks.
    #
    # @api private
    #
    # @param rsconscript [String]
    #   Build script file name.
    # @param tasks_and_params [Hash<String => Hash<String => String>>]
    #   List of task(s) to execute.
    # @param show_tasks [Boolean]
    #   Flag to show tasks and exit.
    #
    # @return [Integer]
    #   Process exit code (0 on success).
    def run(rsconscript, tasks_and_params, show_tasks)
      Cache.instance["failed_commands"] = []
      @script.load(rsconscript)
      if show_tasks
        show_script_tasks
        return 0
      end
      apply_task_params(tasks_and_params)
      if tasks_and_params.empty?
        check_process_environments
        if Task.tasks["default"]
          Task["default"].check_execute
        end
      else
        tasks_and_params.each do |task_name, params|
          Task[task_name].check_execute
        end
      end
      0
    end

    # Show the last failures.
    #
    # @return [void]
    def show_failure
      failed_commands = Cache.instance["failed_commands"]
      failed_commands.each_with_index do |command, i|
        Ansi.write($stdout, :red, "Failed command (#{i + 1}/#{failed_commands.size}):", :reset, "\n")
        $stdout.puts Util.command_to_s(command)
      end
    end

    # Remove all generated files.
    #
    # @api private
    #
    # @return [void]
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
    end

    # Remove the build directory and clear the cache.
    #
    # @api private
    #
    # @return [void]
    def distclean
      cache = Cache.instance
      clean
      FileUtils.rm_rf(@build_dir)
      cache.clear
    end

    # Check if the project needs to be configured.
    #
    # @api private
    #
    # @return [void]
    def check_configure
      unless Cache.instance["configuration_data"]["configured"]
        if @script.autoconf
          configure
        end
      end
    end

    # Check if environments need to be processed.
    #
    # @api private
    #
    # @return [void]
    def check_process_environments
      unless @_processed_environments
        Environment[].each do |env|
          env.process
        end
        @_processed_environments = true
      end
    end

    # Configure the project.
    #
    # @api private
    #
    # @param options [Hash]
    #   Options.
    #
    # @return [void]
    def configure
      co = ConfigureOp.new(@script)
      begin
        @script.configure(co)
      rescue RsconsError => e
        co.close(false)
        raise e
      end
      co.close(true)
    end

    # Remove installed files.
    #
    # @api private
    #
    # @return [Integer]
    #   Exit code.
    #
    # @return [void]
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
    end

    private

    def show_script_tasks
      puts "Tasks:"
      Task[].sort.each do |task_name, task|
        if task.description
          puts %[  #{sprintf("%-27s", task_name)} #{task.description}]
          task.params.each do |param_name, param|
            arg_text = "--#{param_name}"
            if param.takes_arg
              arg_text += "=#{param_name.upcase}"
            end
            puts %[    #{sprintf("%-25s", "#{arg_text}")} #{param.description}]
          end
        end
      end
    end

    def apply_task_params(tasks_and_params)
      tasks_and_params.each do |task_name, task_params|
        task_params.each do |param_name, param_value|
          if param = Task[task_name].params[param_name]
            param.value = param_value
          else
            raise RsconsError.new("Unknown parameter #{param_name.inspect} for task #{task_name}")
          end
        end
      end
    end

  end

end
