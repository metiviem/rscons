module Rscons
  module Builders
    # A default Rscons builder which knows how to produce an object file which
    # is capable of being linked into a shared library from various types of
    # source files.
    class SharedObject < Builder

      # Mapping of known sources from which to build object files.
      KNOWN_SUFFIXES = {
        "AS" => "ASSUFFIX",
        "SHCC" => "CSUFFIX",
        "SHCXX" => "CXXSUFFIX",
        "SHDC" => "DSUFFIX",
      }

      # Run the builder to produce a build target.
      def run(options)
        if @command
          deps = @sources
          if File.exists?(@vars["_DEPFILE"])
            deps += Util.parse_makefile_deps(@vars["_DEPFILE"])
          end
          @cache.register_build(@target, @command, deps.uniq, @env)
          true
        else
          @vars["_TARGET"] = @target
          @vars["_SOURCES"] = @sources
          @vars["_DEPFILE"] = Rscons.set_suffix(target, env.expand_varref("${DEPFILESUFFIX}", vars))
          com_prefix = KNOWN_SUFFIXES.find do |compiler, suffix_var|
            @sources.first.end_with?(*@env.expand_varref("${#{suffix_var}}", @vars))
          end.tap do |v|
            v.nil? and raise "Error: unknown input file type: #{@sources.first.inspect}"
          end.first
          command = @env.build_command("${#{com_prefix}CMD}", @vars)
          @env.produces(@target, @vars["_DEPFILE"])
          verb = com_prefix == "AS" ? "Assembling" : "Compiling"
          message = "#{verb} #{Util.short_format_paths(@sources)}"
          standard_command(message, command)
        end
      end

    end
  end
end
