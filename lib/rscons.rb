require_relative "rscons/build_target"
require_relative "rscons/builder"
require_relative "rscons/cache"
require_relative "rscons/environment"
require_relative "rscons/job_set"
require_relative "rscons/threaded_command"
require_relative "rscons/varset"
require_relative "rscons/version"

# default builders
require_relative "rscons/builders/cfile"
require_relative "rscons/builders/command"
require_relative "rscons/builders/directory"
require_relative "rscons/builders/disassemble"
require_relative "rscons/builders/install"
require_relative "rscons/builders/library"
require_relative "rscons/builders/object"
require_relative "rscons/builders/preprocess"
require_relative "rscons/builders/program"
require_relative "rscons/builders/simple_builder"

# Namespace module for rscons classes
module Rscons

  # Names of the default builders which will be added to all newly created
  # {Environment} objects.
  DEFAULT_BUILDERS = [
    :CFile,
    :Command,
    :Copy,
    :Directory,
    :Disassemble,
    :Install,
    :Library,
    :Object,
    :Preprocess,
    :Program,
  ]

  # Class to represent a fatal error while building a target.
  class BuildError < RuntimeError; end

  class << self

    # @return [Integer]
    #   The number of threads to use when scheduling subprocesses.
    attr_accessor :n_threads

    # Remove all generated files.
    #
    # @return [void]
    def clean
      cache = Cache.instance
      # remove all built files
      cache.targets.each do |target|
        FileUtils.rm_f(target)
      end
      # remove all created directories if they are empty
      cache.directories.sort {|a, b| b.size <=> a.size}.each do |directory|
        next unless File.directory?(directory)
        if (Dir.entries(directory) - ['.', '..']).empty?
          Dir.rmdir(directory) rescue nil
        end
      end
      cache.clear
    end

    # Return whether the given path is an absolute filesystem path.
    #
    # @param path [String] the path to examine.
    #
    # @return [Boolean] Whether the given path is an absolute filesystem path.
    def absolute_path?(path)
      path =~ %r{^(/|\w:[\\/])}
    end

    # Return whether the given target is a phony target.
    #
    # @param target [Symbol, String] Target name.
    #
    # @return [Boolean] Whether the given target is a phony target.
    def phony_target?(target)
      target.is_a?(Symbol)
    end

    # Return a new path by changing the suffix in path to suffix.
    #
    # @param path [String] The path to alter.
    # @param suffix [String] The new filename suffix, e.g. ".exe".
    #
    # @return [String] New path.
    def set_suffix(path, suffix)
      path.sub(/\.[^.]*$/, "") + suffix
    end

    # Return the system shell and arguments for executing a shell command.
    #
    # @return [Array<String>] The shell and flag.
    def get_system_shell
      @shell ||=
        begin
          test_shell = lambda do |*args|
            begin
              "success" == IO.popen([*args, "echo success"]) do |io|
                io.read.strip
              end
            rescue
              false
            end
          end
          if ENV["SHELL"] and ENV["SHELL"] != "" and test_shell[ENV["SHELL"], "-c"]
            [ENV["SHELL"], "-c"]
          elsif Object.const_get("RUBY_PLATFORM") =~ /mingw/
            if test_shell["sh", "-c"]
              # Using Rscons from MSYS should use MSYS's shell.
              ["sh", "-c"]
            else
              ["cmd", "/c"]
            end
          else
            ["sh", "-c"]
          end
        end
    end

    # Return an Array containing a command used to execute commands.
    #
    # This will normally be an empty Array, but on Windows if Rscons detects
    # that it is running in MSYS then ["env"] will be returned.
    #
    # @return [Array<String>] Command used to execute commands.
    def command_executer
      @command_executer ||=
        if Object.const_get("RUBY_PLATFORM") =~ /mingw/
          if ENV.keys.find {|key| key =~ /MSYS/}
            begin
              if IO.popen(["env", "echo", "success"]) {|io| io.read.strip} == "success"
                ["env"]
              end
            rescue
            end
          end
        end || []
    end

    # Set the command executer array.
    #
    # @param val [Array<String>] Command used to execute commands.
    #
    # @return [Array<String>] Command used to execute commands.
    def command_executer=(val)
      @command_executer = val
    end

    private

    # Determine the number of threads to use by default.
    #
    # @return [Integer]
    #   The number of threads to use by default.
    def determine_n_threads
      # If the user specifies the number of threads in the environment, then
      # respect that.
      if ENV["RSCONS_NTHREADS"] =~ /^(\d+)$/
        return $1.to_i
      end

      # Otherwise try to figure out how many threads are available on the
      # host hardware.
      begin
        case RbConfig::CONFIG["host_os"]
        when /linux/
          return File.read("/proc/cpuinfo").scan(/^processor\s*:/).size
        when /mswin|mingw/
          if `wmic cpu get NumberOfLogicalProcessors /value` =~ /NumberOfLogicalProcessors=(\d+)/
            return $1.to_i
          end
        when /darwin/
          if `sysctl -n hw.ncpu` =~ /(\d+)/
            return $1.to_i
          end
        end
      rescue
      end

      # If we can't figure it out, default to 1.
      1
    end

  end

  @n_threads = determine_n_threads

end

# Unbuffer $stdout
$stdout.sync = true
