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

      # Return default construction variables for the builder.
      #
      # @param env [Environment] The Environment using the builder.
      #
      # @return [Hash] Default construction variables for the builder.
      def default_variables(env)
        {
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
          'D_IMPORT_PATH' => [],
          'DCCMD' => ['${DC}', '-c', '-o', '${_TARGET}', '${INCPREFIX}${D_IMPORT_PATH}', '${DFLAGS}', '${_SOURCES}'],
        }
      end

      # Return whether this builder object is capable of producing a given target
      # file name from a given source file name.
      #
      # @param options [Hash]
      #   Options.
      #
      # @return [Boolean]
      #   Whether this builder object is capable of producing a given target
      #   file name from a given source file name.
      def produces?(options)
        target, source, env, features = options.values_at(:target, :source, :env, :features)
        (not features[:shared]) and
          target.end_with?(*env['OBJSUFFIX']) and
          KNOWN_SUFFIXES.find do |compiler, suffix_var|
            source.end_with?(*env[suffix_var])
          end
      end

      # Run the builder to produce a build target.
      #
      # @param options [Hash] Builder run options.
      #
      # @return [String, ThreadedCommand]
      #   Target file name if target is up to date or a {ThreadedCommand}
      #   to execute to build the target.
      def run(options)
        target, sources, cache, env, vars = options.values_at(:target, :sources, :cache, :env, :vars)
        vars = vars.merge({
          '_TARGET' => target,
          '_SOURCES' => sources,
          '_DEPFILE' => Rscons.set_suffix(target, env.expand_varref("${DEPFILESUFFIX}", vars)),
        })
        com_prefix = KNOWN_SUFFIXES.find do |compiler, suffix_var|
          sources.first.end_with?(*env.expand_varref("${#{suffix_var}}"))
        end.tap do |v|
          v.nil? and raise "Error: unknown input file type: #{sources.first.inspect}"
        end.first
        command = env.build_command("${#{com_prefix}CMD}", vars)
        # Store vars back into options so new keys are accessible in #finalize.
        options[:vars] = vars
        standard_threaded_build("#{com_prefix} #{target}", target, command, sources, env, cache)
      end

      # Finalize the build operation.
      #
      # @param options [Hash] Builder finalize options.
      #
      # @return [String, nil]
      #   Name of the target file on success or nil on failure.
      def finalize(options)
        if options[:command_status]
          target, deps, cache, env, vars = options.values_at(:target, :sources, :cache, :env, :vars)
          if File.exists?(vars['_DEPFILE'])
            deps += Environment.parse_makefile_deps(vars['_DEPFILE'], target)
            FileUtils.rm_f(vars['_DEPFILE'])
          end
          cache.register_build(target, options[:tc].command, deps.uniq, env)
          target
        end
      end

    end
  end
end
