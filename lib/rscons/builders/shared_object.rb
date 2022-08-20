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

      # Return default construction variables for the builder.
      #
      # @param env [Environment] The Environment using the builder.
      #
      # @return [Hash] Default construction variables for the builder.
      def default_variables(env)
        pic_flags = (RUBY_PLATFORM =~ /mingw/ ? [] : ['-fPIC'])
        {
          'SHCCFLAGS' => ['${CCFLAGS}'] + pic_flags,

          'SHCC' => '${CC}',
          'SHCFLAGS' => ['${CFLAGS}'],
          'SHCCCMD' => ['${SHCC}', '-c', '-o', '${_TARGET}', '${CCDEPGEN}', '${INCPREFIX}${CPPPATH}', '${CPPFLAGS}', '${SHCFLAGS}', '${SHCCFLAGS}', '${_SOURCES}'],

          'SHCXX' => '${CXX}',
          'SHCXXFLAGS' => ['${CXXFLAGS}'],
          'SHCXXCMD' => ['${SHCXX}', '-c', '-o', '${_TARGET}', '${CXXDEPGEN}', '${INCPREFIX}${CPPPATH}', '${CPPFLAGS}', '${SHCXXFLAGS}', '${SHCCFLAGS}', '${_SOURCES}'],

          'SHDC' => 'gdc',
          'SHDFLAGS' => ['${DFLAGS}'] + pic_flags,
          'SHDCCMD' => ['${SHDC}', '-c', '-o', '${_TARGET}', '${INCPREFIX}${D_IMPORT_PATH}', '${SHDFLAGS}', '${_SOURCES}'],
        }
      end

      # Return a set of build features that this builder provides.
      #
      # @return [Array<String>]
      #   Set of build features that this builder provides.
      def features
        %w[shared]
      end

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
          sources.first.end_with?(*env.expand_varref("${#{suffix_var}}", vars))
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
          if File.exist?(vars['_DEPFILE'])
            deps += Environment.parse_makefile_deps(vars['_DEPFILE'])
            FileUtils.rm_f(vars['_DEPFILE'])
          end
          cache.register_build(target, options[:tc].command, deps.uniq, env)
          target
        end
      end

    end
  end
end
