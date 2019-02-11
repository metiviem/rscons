module Rscons
  module Util
    class << self

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

      # Return a string representation of a command.
      #
      # @param command [Array<String>]
      #   The command.
      #
      # @return [String]
      #   The string representation of the command.
      def command_to_s(command)
        command.map { |c| c =~ /\s/ ? "'#{c}'" : c }.join(' ')
      end

      # Look for an executable.
      #
      # @return [String, nil]
      #   Executable path, if found.
      def find_executable(name)
        if name["/"] or name["\\"]
          if File.file?(name) and File.executable?(name)
            return name
          end
        else
          path_entries = ENV["PATH"].split(File::PATH_SEPARATOR)
          path_entries.find do |path_entry|
            if path = test_path_for_executable(path_entry, name)
              return path
            end
          end
        end
      end

      # Make a relative path corresponding to a possibly absolute one.
      #
      # @param path [String]
      #   Input path that is possibly absolute.
      #
      # @return [String]
      #   Relative path.
      def make_relative_path(path)
        if absolute_path?(path)
          if path =~ %r{^(\w):(.*)$}
            "_#{$1}#{$2}"
          else
            "_#{path}"
          end
        else
          path
        end
      end

      # Parse dependencies from a Makefile.
      #
      # This method is used internally by Rscons builders.
      #
      # @param mf_fname [String]
      #   File name of the Makefile to read.
      #
      # @return [Array<String>]
      #   Paths of dependency files.
      def parse_makefile_deps(mf_fname)
        deps = []
        buildup = ''
        File.read(mf_fname).each_line do |line|
          if line =~ /^(.*)\\\s*$/
            buildup += ' ' + $1
          else
            buildup += ' ' + line
            if buildup =~ /^.*: (.*)$/
              mf_deps = $1
              deps += mf_deps.split(' ').map(&:strip)
            end
            buildup = ''
          end
        end
        deps
      end

      private

      # Check if a directory contains a certain executable.
      #
      # @param path_entry [String]
      #   Directory to look in.
      # @param executable [String]
      #   Executable to look for.
      def test_path_for_executable(path_entry, executable)
        is_executable = lambda do |path|
          File.file?(path) and File.executable?(path)
        end
        if RbConfig::CONFIG["host_os"] =~ /mswin|windows|mingw/i
          executable = executable.downcase
          dir_entries = Dir.entries(path_entry)
          dir_entries.find do |entry|
            path = "#{path_entry}/#{entry}"
            entry = entry.downcase
            if ((entry == executable) or
                (entry == "#{executable}.exe") or
                (entry == "#{executable}.com") or
                (entry == "#{executable}.bat")) and is_executable[path]
              return path
            end
          end
        else
          path = "#{path_entry}/#{executable}"
          return path if is_executable[path]
        end
      end

    end
  end
end
