require "digest/md5"
require "fileutils"
require "json"
require "set"
require "rscons/version"

module Rscons
  # The Cache class keeps track of file checksums, build target commands and
  # dependencies in a JSON file which persists from one invocation to the next.
  # Example cache:
  #   {
  #     "version" => "1.2.3",
  #     "targets" => {
  #       "program" => {
  #         "checksum" => "A1B2C3D4",
  #         "command" => "13543518FE",
  #         "deps" => [
  #           {
  #             "fname" => "program.o",
  #             "checksum" => "87654321",
  #           },
  #         ],
  #         "user_deps" => [
  #           {
  #             "fname" => "lscript.ld",
  #             "checksum" => "77551133",
  #           },
  #         ],
  #       },
  #       "program.o" => {
  #         "checksum" => "87654321",
  #         "command" => "98765ABCD",
  #         "deps" => [
  #           {
  #             "fname" => "program.c",
  #             "checksum" => "456789ABC",
  #           },
  #           {
  #             "fname" => "program.h",
  #             "checksum" => "7979764643",
  #           },
  #         ],
  #         "user_deps" => [],
  #       }
  #     },
  #     "directories" => {
  #       "build" => true,
  #       "build/one" => true,
  #       "build/two" => true,
  #     },
  #   }
  class Cache

    # Name of the file to store cache information in
    CACHE_FILE = ".rsconscache"

    # Prefix for phony cache entries.
    PHONY_PREFIX = ":PHONY:"

    class << self
      # Access the singleton instance.
      def instance
        @instance ||= Cache.new
      end
    end

    # Create a Cache object and load in the previous contents from the cache
    # file.
    def initialize
      initialize!
    end

    # Remove the cache file.
    #
    # @return [void]
    def clear
      FileUtils.rm_f(CACHE_FILE)
      initialize!
    end

    # Clear the cached file checksums.
    #
    # @return [void]
    def clear_checksum_cache!
      @lookup_checksums = {}
    end

    # Write the cache to disk to be loaded next time.
    #
    # @return [void]
    def write
      if @dirty || (@cache["version"] != VERSION)
        @cache["version"] = VERSION
        File.open(CACHE_FILE, "w") do |fh|
          fh.puts(JSON.dump(@cache))
        end
      end
      @dirty = false
    end

    # Check if target(s) are up to date.
    #
    # @param targets [Symbol, String, Array<String>]
    #   The name(s) of the target file(s).
    # @param command [String, Array, Hash]
    #   The command used to build the target. The command parameter can
    #   actually be a String, Array, or Hash and could contain information
    #   other than just the actual command used to build the target. For the
    #   purposes of the Cache, any difference in the command argument will
    #   trigger a rebuild.
    # @param deps [Array<String>] List of the target's dependency files.
    # @param env [Environment] The Rscons::Environment.
    # @param options [Hash] Optional options.
    # @option options [Boolean] :debug
    #   If turned on, this causes the Cache to print messages explaining why
    #   a build target is out of date. This could aid a builder author in
    #   debugging the operation of their builder.
    # @option options [Boolean] :strict_deps
    #   Only consider a target up to date if its list of dependencies is
    #   exactly equal (including order) to the cached list of dependencies
    #
    # @return [Boolean]
    #   True value if the targets are all up to date, meaning that,
    #   for each target:
    #   - the target exists on disk
    #   - the cache has information for the target
    #   - the target's checksum matches its checksum when it was last built
    #   - the command used to build the target is the same as last time
    #   - all dependencies listed are also listed in the cache, or, if
    #     :strict_deps was given in options, the list of dependencies is
    #     exactly equal to those cached
    #   - each cached dependency file's current checksum matches the checksum
    #     stored in the cache file
    def up_to_date?(targets, command, deps, env, options = {})
      Array(targets).each do |target|
        cache_key = get_cache_key(target)

        unless Rscons.phony_target?(target)
          # target file must exist on disk
          unless File.exists?(target)
            if options[:debug]
              puts "Target #{target} needs rebuilding because it does not exist on disk"
            end
            return false
          end
        end

        # target must be registered in the cache
        unless @cache["targets"].has_key?(cache_key)
          if options[:debug]
            puts "Target #{target} needs rebuilding because there is no cached build information for it"
          end
          return false
        end

        unless Rscons.phony_target?(target)
          # target must have the same checksum as when it was built last
          unless @cache["targets"][cache_key]["checksum"] == lookup_checksum(target)
            if options[:debug]
              puts "Target #{target} needs rebuilding because it has been changed on disk since being built last"
            end
            return false
          end
        end

        # command used to build target must be identical
        unless @cache["targets"][cache_key]["command"] == Digest::MD5.hexdigest(command.inspect)
          if options[:debug]
            puts "Target #{target} needs rebuilding because the command used to build it has changed"
          end
          return false
        end

        cached_deps = @cache["targets"][cache_key]["deps"] || []
        cached_deps_fnames = cached_deps.map { |dc| dc["fname"] }
        if options[:strict_deps]
          # depedencies passed in must exactly equal those in the cache
          unless deps == cached_deps_fnames
            if options[:debug]
              puts "Target #{target} needs rebuilding because the :strict_deps option is given and the set of dependencies does not match the previous set of dependencies"
            end
            return false
          end
        else
          # all dependencies passed in must exist in cache (but cache may have more)
          unless (Set.new(deps) - Set.new(cached_deps_fnames)).empty?
            if options[:debug]
              puts "Target #{target} needs rebuilding because there are new dependencies"
            end
            return false
          end
        end

        # set of user dependencies must match
        user_deps = env.get_user_deps(target) || []
        cached_user_deps = @cache["targets"][cache_key]["user_deps"] || []
        cached_user_deps_fnames = cached_user_deps.map { |dc| dc["fname"] }
        unless user_deps == cached_user_deps_fnames
          if options[:debug]
            puts "Target #{target} needs rebuilding because the set of user-specified dependency files has changed"
          end
          return false
        end

        # all cached dependencies must have their checksums match
        (cached_deps + cached_user_deps).each do |dep_cache|
          unless dep_cache["checksum"] == lookup_checksum(dep_cache["fname"])
            if options[:debug]
              puts "Target #{target} needs rebuilding because dependency file #{dep_cache["fname"]} has changed"
            end
            return false
          end
        end
      end

      true
    end

    # Store cache information about target(s) built by a builder.
    #
    # @param targets [Symbol, String, Array<String>]
    #   The name of the target(s) built.
    # @param command [String, Array, Hash]
    #   The command used to build the target. The command parameter can
    #   actually be a String, Array, or Hash and could contain information
    #   other than just the actual command used to build the target. For the
    #   purposes of the Cache, any difference in the command argument will
    #   trigger a rebuild.
    # @param deps [Array<String>] List of dependencies for the target.
    # @param env [Environment] The {Rscons::Environment}.
    #
    # @return [void]
    def register_build(targets, command, deps, env)
      Array(targets).each do |target|
        target_checksum = Rscons.phony_target?(target) ? "" : calculate_checksum(target)
        @cache["targets"][get_cache_key(target)] = {
          "command" => Digest::MD5.hexdigest(command.inspect),
          "checksum" => target_checksum,
          "deps" => deps.map do |dep|
            {
              "fname" => dep,
              "checksum" => lookup_checksum(dep),
            }
          end,
          "user_deps" => (env.get_user_deps(target) || []).map do |dep|
            {
              "fname" => dep,
              "checksum" => lookup_checksum(dep),
            }
          end,
        }
        @dirty = true
      end
    end

    # Return a list of targets that have been built.
    #
    # @return [Array<String>] List of targets that have been built.
    def targets
      @cache["targets"].keys
    end

    # Make any needed directories and record the ones that are created for
    # removal upon a "clean" operation.
    #
    # @param path [String] Directory to create.
    #
    # @return [void]
    def mkdir_p(path)
      parts = path.split(/[\\\/]/)
      parts.each_index do |i|
        next if parts[i] == ""
        subpath = File.join(*parts[0, i + 1])
        unless File.exists?(subpath)
          FileUtils.mkdir_p(subpath)
          @cache["directories"][subpath] = true
          @dirty = true
        end
      end
    end

    # Return a list of directories which were created as a part of the build.
    #
    # @return [Array<String>]
    #   List of directories which were created as a part of the build.
    def directories
      @cache["directories"].keys
    end

    private

    # Return a String key based on the target name to use in the on-disk cache.
    #
    # @param target_name [Symbol, String]
    #   Target name.
    #
    # @return [String]
    #   Key name.
    def get_cache_key(target_name)
      if Rscons.phony_target?(target_name)
        PHONY_PREFIX + target_name.to_s
      else
        target_name
      end
    end

    # Create a Cache object and load in the previous contents from the cache
    # file.
    def initialize!
      @cache = JSON.load(File.read(CACHE_FILE)) rescue {}
      unless @cache.is_a?(Hash)
        $stderr.puts "Warning: #{CACHE_FILE} was corrupt. Contents:\n#{@cache.inspect}"
        @cache = {}
      end
      @cache["targets"] ||= {}
      @cache["directories"] ||= {}
      @lookup_checksums = {}
      @dirty = false
    end

    # Return a file's checksum, or the previously calculated checksum for
    # the same file.
    #
    # @param file [String] The file name.
    #
    # @return [String] The file's checksum.
    def lookup_checksum(file)
      @lookup_checksums[file] || calculate_checksum(file)
    end

    # Calculate and return a file's checksum.
    #
    # @param file [String] The file name.
    #
    # @return [String] The file's checksum.
    def calculate_checksum(file)
      @lookup_checksums[file] = Digest::MD5.hexdigest(File.read(file, mode: "rb")) rescue ""
    end
  end
end
