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
    #   Whether to run verbosely.
    attr_accessor :verbose

    # Create Application instance.
    def initialize
      @script = Script.new
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
    # @param tasks [Array<String>]
    #   List of task(s) to execute.
    #
    # @return [Integer]
    #   Process exit code (0 on success).
    def run(tasks)
      Cache.instance["failed_commands"] = []
      tasks.each do |task|
        Task[task].check_execute
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

  end

end
