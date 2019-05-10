module Rscons
  # The BasicEnvironment class contains a collection of construction variables.
  class BasicEnvironment

    # Create a BasicEnvironment object.
    #
    # @api private
    #
    # @param options [Hash]
    #   Construction options.
    def initialize(options = {})
      @varset = VarSet.new(Rscons::DEFAULT_CONSTRUCTION_VARIABLES)
      load_configuration_data!(options)
    end

    # Access the value of a construction variable.
    #
    # @param key [String, Symbol]
    #   The construction variable name.
    #
    # @return [Object]
    #   The construction variable's value.
    def [](key)
      @varset[key]
    end

    # Access the value of a construction variable.
    #
    # This method is similar to #[] but does not make a copy-on-access copy of
    # the variable accessed. This means that the returned value is NOT safe to
    # be modified by the caller. Thus the caller must guarantee that it does
    # not modify the returned value.
    #
    # @param key [String, Symbol]
    #   The construction variable name.
    #
    # @return [Object]
    #   The construction variable's value.
    def get_var(key)
      @varset.get_var(key)
    end

    # Assign a value to a construction variable.
    #
    # @param key [String, Symbol]
    #   The construction variable name.
    #
    # @param val [Object]
    #   The value to set.
    def []=(key, val)
      @varset[key] = val
    end

    # Add a set of construction variables to the BasicEnvironment.
    #
    # @param values [VarSet, Hash] New set of variables.
    #
    # @return [void]
    def append(values)
      @varset.append(values)
    end

    # Expand a construction variable reference.
    #
    # @param varref [nil, String, Array, Proc, Symbol, TrueClass, FalseClass] Variable reference to expand.
    # @param extra_vars [Hash, VarSet]
    #   Extra variables to use in addition to (or replace) the Environment's
    #   construction variables when expanding the variable reference.
    #
    # @return [nil, String, Array, Symbol, TrueClass, FalseClass] Expansion of the variable reference.
    def expand_varref(varref, extra_vars = nil)
      vars =
        if extra_vars.nil?
          @varset
        else
          @varset.merge(extra_vars)
        end
      lambda_args = [env: self, vars: vars]
      vars.expand_varref(varref, lambda_args)
    end
    alias_method :build_command, :expand_varref

    # @!method parse_flags(flags)
    # @!method parse_flags!(flags)
    #
    # Parse command-line flags for compilation/linking options into separate
    # construction variables.
    #
    # For {#parse_flags}, the parsed construction variables are returned in a
    # Hash instead of merging them directly to the Environment. They can be
    # merged with {#merge_flags}. The {#parse_flags!} version immediately
    # merges the parsed flags as well.
    #
    # Example:
    #   # Import FreeType build options
    #   env.parse_flags!("!freetype-config --cflags --libs")
    #
    # @param flags [String]
    #   String containing the flags to parse, or if the flags string begins
    #   with "!", a shell command to execute using {#shell} to obtain the
    #   flags to parse.
    #
    # @return [Hash] Set of construction variables to append.
    def parse_flags(flags)
      if flags =~ /^!(.*)$/
        flags = shell($1)
      end
      rv = {}
      words = Shellwords.split(flags)
      skip = false
      words.each_with_index do |word, i|
        if skip
          skip = false
          next
        end
        append = lambda do |var, val|
          rv[var] ||= []
          rv[var] += val
        end
        handle = lambda do |var, val|
          if val.nil? or val.empty?
            val = words[i + 1]
            skip = true
          end
          if val and not val.empty?
            append[var, [val]]
          end
        end
        if word == "-arch"
          if val = words[i + 1]
            append["CCFLAGS", ["-arch", val]]
            append["LDFLAGS", ["-arch", val]]
          end
          skip = true
        elsif word =~ /^#{get_var("CPPDEFPREFIX")}(.*)$/
          handle["CPPDEFINES", $1]
        elsif word == "-include"
          if val = words[i + 1]
            append["CCFLAGS", ["-include", val]]
          end
          skip = true
        elsif word == "-isysroot"
          if val = words[i + 1]
            append["CCFLAGS", ["-isysroot", val]]
            append["LDFLAGS", ["-isysroot", val]]
          end
          skip = true
        elsif word =~ /^#{get_var("INCPREFIX")}(.*)$/
          handle["CPPPATH", $1]
        elsif word =~ /^#{get_var("LIBLINKPREFIX")}(.*)$/
          handle["LIBS", $1]
        elsif word =~ /^#{get_var("LIBDIRPREFIX")}(.*)$/
          handle["LIBPATH", $1]
        elsif word == "-mno-cygwin"
          append["CCFLAGS", [word]]
          append["LDFLAGS", [word]]
        elsif word == "-mwindows"
          append["LDFLAGS", [word]]
        elsif word == "-pthread"
          append["CCFLAGS", [word]]
          append["LDFLAGS", [word]]
        elsif word =~ /^-Wa,(.*)$/
          append["ASFLAGS", $1.split(",")]
        elsif word =~ /^-Wl,(.*)$/
          append["LDFLAGS", $1.split(",")]
        elsif word =~ /^-Wp,(.*)$/
          append["CPPFLAGS", $1.split(",")]
        elsif word.start_with?("-")
          append["CCFLAGS", [word]]
        elsif word.start_with?("+")
          append["CCFLAGS", [word]]
          append["LDFLAGS", [word]]
        else
          append["LIBS", [word]]
        end
      end
      rv
    end

    def parse_flags!(flags)
      flags = parse_flags(flags)
      merge_flags(flags)
      flags
    end

    # Merge construction variable flags into this Environment's construction
    # variables.
    #
    # This method does the same thing as {#append}, except that Array values in
    # +flags+ are appended to the end of Array construction variables instead
    # of replacing their contents.
    #
    # @param flags [Hash]
    #   Set of construction variables to merge into the current Environment.
    #   This can be the value (or a modified version) returned by
    #   {#parse_flags}.
    #
    # @return [void]
    def merge_flags(flags)
      flags.each_pair do |key, val|
        if self.get_var(key).is_a?(Array) and val.is_a?(Array)
          self[key] += val
        else
          self[key] = val
        end
      end
    end

    # Print the Environment's construction variables for debugging.
    def dump
      varset_hash = @varset.to_h
      varset_hash.keys.sort_by(&:to_s).each do |var|
        var_str = var.is_a?(Symbol) ? var.inspect : var
        Ansi.write($stdout, :cyan, var_str, :reset, " => #{varset_hash[var].inspect}\n")
      end
    end

    # Load all construction variables saved from the configure operation.
    def load_configuration_data!(options)
      if vars = Cache.instance["configuration_data"]["vars"]
        if default_vars = vars["_default_"]
          apply_configuration_data!(default_vars)
        end
        if options[:use]
          Array(options[:use]).each do |use|
            if use_vars = vars[use]
              apply_configuration_data!(use_vars)
            end
          end
        end
      end
    end

    # Load a specific set of construction variables saved from the configure
    # operation.
    def apply_configuration_data!(vars)
      if merge_vars = vars["merge"]
        append(merge_vars)
      end
      if append_vars = vars["append"]
        merge_flags(append_vars)
      end
      if parse_vars = vars["parse"]
        parse_vars.each do |parse_string|
          parse_flags!(parse_string)
        end
      end
    end

    # Execute a command using the system shell.
    #
    # The shell is automatically determined but can be overridden by the SHELL
    # construction variable. If the SHELL construction variable is specified,
    # the flag to pass to the shell is automatically dtermined but can be
    # overridden by the SHELLFLAG construction variable.
    #
    # @param command [String] Command to execute.
    #
    # @return [String] The command's standard output.
    def shell(command)
      shell_cmd =
        if shell = get_var("SHELL")
          flag = get_var("SHELLFLAG") || (shell == "cmd" ? "/c" : "-c")
          [shell, flag]
        else
          Rscons.get_system_shell
        end
      IO.popen([*shell_cmd, command]) do |io|
        io.read
      end
    end

  end
end
