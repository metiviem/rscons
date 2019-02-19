module Rscons
  module Builders
    # A default Rscons builder which knows how to produce an object file from
    # various types of source files.
    class Object < Builder

      # Mapping of known sources from which to build object files.
      KNOWN_SUFFIXES = {
        "AS" => "ASSUFFIX",
        "CC" => "CSUFFIX",
        "CXX" => "CXXSUFFIX",
        "DC" => "DSUFFIX",
      }

      Rscons.application.default_varset.append(
        'OBJSUFFIX' => ['.o'],
        'DEPFILESUFFIX' => '.mf',

        'CPPDEFPREFIX' => '-D',
        'INCPREFIX' => '-I',

        'AS' => '${CC}',
        'ASFLAGS' => [],
        'ASSUFFIX' => ['.S'],
        'ASPPPATH' => '${CPPPATH}',
        'ASPPFLAGS' => '${CPPFLAGS}',
        'ASDEPGEN' => ['-MMD', '-MF', '${_DEPFILE}'],
        'ASCMD' => ['${AS}', '-c', '-o', '${_TARGET}', '${ASDEPGEN}', '${INCPREFIX}${ASPPPATH}', '${ASPPFLAGS}', '${ASFLAGS}', '${_SOURCES}'],

        'CPPFLAGS' => ['${CPPDEFPREFIX}${CPPDEFINES}'],
        'CPPDEFINES' => [],
        'CPPPATH' => [],

        'CCFLAGS' => [],

        'CC' => 'gcc',
        'CFLAGS' => [],
        'CSUFFIX' => ['.c'],
        'CCDEPGEN' => ['-MMD', '-MF', '${_DEPFILE}'],
        'CCCMD' => ['${CC}', '-c', '-o', '${_TARGET}', '${CCDEPGEN}', '${INCPREFIX}${CPPPATH}', '${CPPFLAGS}', '${CFLAGS}', '${CCFLAGS}', '${_SOURCES}'],

        'CXX' => 'g++',
        'CXXFLAGS' => [],
        'CXXSUFFIX' => ['.cc', '.cpp', '.cxx', '.C'],
        'CXXDEPGEN' => ['-MMD', '-MF', '${_DEPFILE}'],
        'CXXCMD' =>['${CXX}', '-c', '-o', '${_TARGET}', '${CXXDEPGEN}', '${INCPREFIX}${CPPPATH}', '${CPPFLAGS}', '${CXXFLAGS}', '${CCFLAGS}', '${_SOURCES}'],

        'DC' => 'gdc',
        'DFLAGS' => [],
        'DSUFFIX' => ['.d'],
        'DDEPGEN' => ['-MMD', '-MF', '${_DEPFILE}'],
        'D_IMPORT_PATH' => [],
        'DCCMD' => ['${DC}', '-c', '-o', '${_TARGET}', '${DDEPGEN}', '${INCPREFIX}${D_IMPORT_PATH}', '${DFLAGS}', '${_SOURCES}'],
      )

      class << self
        # Return whether this builder object is capable of producing a given target
        # file name from a given source file name.
        #
        # @param target [String]
        #   The target file name.
        # @param source [String]
        #   The source file name.
        # @param env [Environment]
        #   The Environment.
        #
        # @return [Boolean]
        #   Whether this builder object is capable of producing a given target
        #   file name from a given source file name.
        def produces?(target, source, env)
          target.end_with?(*env['OBJSUFFIX']) and
            KNOWN_SUFFIXES.find do |compiler, suffix_var|
              source.end_with?(*env[suffix_var])
            end
        end
      end

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
