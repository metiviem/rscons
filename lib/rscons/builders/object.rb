module Rscons
  module Builders
    # A default Rscons builder which knows how to produce an object file from
    # various types of source files.
    class Object < Builder
      KNOWN_SUFFIXES = {
        "AS" => "ASSUFFIX",
        "CC" => "CSUFFIX",
        "CXX" => "CXXSUFFIX",
        "DC" => "DSUFFIX",
      }

      def default_variables(env)
        {
          'OBJSUFFIX' => '.o',

          'CPPDEFPREFIX' => '-D',
          'INCPREFIX' => '-I',

          'AS' => '${CC}',
          'ASFLAGS' => [],
          'ASSUFFIX' => '.S',
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
          'CSUFFIX' => '.c',
          'CCDEPGEN' => ['-MMD', '-MF', '${_DEPFILE}'],
          'CCCMD' => ['${CC}', '-c', '-o', '${_TARGET}', '${CCDEPGEN}', '${INCPREFIX}${CPPPATH}', '${CPPFLAGS}', '${CFLAGS}', '${CCFLAGS}', '${_SOURCES}'],

          'CXX' => 'g++',
          'CXXFLAGS' => [],
          'CXXSUFFIX' => '.cc',
          'CXXDEPGEN' => ['-MMD', '-MF', '${_DEPFILE}'],
          'CXXCMD' =>['${CXX}', '-c', '-o', '${_TARGET}', '${CXXDEPGEN}', '${INCPREFIX}${CPPPATH}', '${CPPFLAGS}', '${CXXFLAGS}', '${CCFLAGS}', '${_SOURCES}'],

          'DC' => 'gdc',
          'DFLAGS' => [],
          'DSUFFIX' => '.d',
          'D_IMPORT_PATH' => [],
          'DCCMD' => ['${DC}', '-c', '-o', '${_TARGET}', '${INCPREFIX}${D_IMPORT_PATH}', '${DFLAGS}', '${_SOURCES}'],
        }
      end

      def produces?(target, source, env)
        target.end_with?(*env['OBJSUFFIX']) and KNOWN_SUFFIXES.find do |compiler, suffix_var|
          source.end_with?(*env[suffix_var])
        end
      end

      def run(target, sources, cache, env, vars)
        vars = vars.merge({
          '_TARGET' => target,
          '_SOURCES' => sources,
          '_DEPFILE' => Rscons.set_suffix(target, '.mf'),
        })
        com_prefix = KNOWN_SUFFIXES.find do |compiler, suffix_var|
          sources.first.end_with?(*env.expand_varref("${#{suffix_var}}"))
        end.tap do |v|
          v.nil? and raise "Error: unknown input file type: #{sources.first.inspect}"
        end.first
        command = env.build_command("${#{com_prefix}CMD}", vars)
        unless cache.up_to_date?(target, command, sources, env)
          cache.mkdir_p(File.dirname(target))
          FileUtils.rm_f(target)
          return false unless env.execute("#{com_prefix} #{target}", command)
          deps = sources
          if File.exists?(vars['_DEPFILE'])
            deps += Environment.parse_makefile_deps(vars['_DEPFILE'], target)
            FileUtils.rm_f(vars['_DEPFILE'])
          end
          cache.register_build(target, command, deps.uniq, env)
        end
        target
      end
    end
  end
end
