require_relative "rscons/ansi"
require_relative "rscons/application"
require_relative "rscons/build_target"
require_relative "rscons/builder"
require_relative "rscons/cache"
require_relative "rscons/environment"
require_relative "rscons/job_set"
require_relative "rscons/script"
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
require_relative "rscons/builders/shared_library"
require_relative "rscons/builders/shared_object"
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
    :SharedLibrary,
    :SharedObject,
  ]

  # Class to represent a fatal error while building a target.
  class BuildError < RuntimeError; end

  class << self

    # Access the Application singleton.
    #
    # @return [Application]
    #   The Application singleton.
    def application
      @application ||= Application.new
    end

    # Access any variables set on the rscons command-line.
    #
    # @return [VarSet]
    def vars(*args)
      application.vars(*args)
    end

    # Return whether the given path is an absolute filesystem path.
    #
    # @param path [String] the path to examine.
    #
    # @return [Boolean] Whether the given path is an absolute filesystem path.
    def absolute_path?(path)
      if RUBY_PLATFORM =~ /mingw/
        path =~ %r{^(?:\w:)?[\\/]}
      else
        path.start_with?("/")
      end
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

    # Return a list of paths matching the specified pattern(s).
    #
    # @since 1.16.0
    #
    # A pattern can contain a "/**" component to recurse through directories.
    # If the pattern ends with "/**" then only the recursive list of
    # directories will be returned.
    #
    # Examples:
    # - "src/**": return all directories under "src", recursively (including
    #   "src" itself).
    # - "src/**/*": return all files and directories recursively under the src
    #   directory.
    # - "src/**/*.c": return all .c files recursively under the src directory.
    # - "dir/*/": return all directories in dir, but no files.
    #
    # @return [Array<String>] Paths matching the specified pattern(s).
    def glob(*patterns)
      require "pathname"
      patterns.reduce([]) do |result, pattern|
        if pattern.end_with?("/**")
          pattern += "/"
        end
        result += Dir.glob(pattern).map do |path|
          Pathname.new(path.gsub("\\", "/")).cleanpath.to_s
        end
      end.sort
    end

  end

end

# Unbuffer $stdout
$stdout.sync = true
