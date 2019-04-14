module Rscons
  # This class represents a collection of variables which supports efficient
  # deep cloning.
  class VarSet
    # Create a VarSet.
    #
    # @param vars [Hash] Optional initial variables.
    def initialize(vars = {})
      @my_vars = {}
      @coa_vars = []
      append(vars)
    end

    # Access the value of variable.
    #
    # @param key [String, Symbol] The variable name.
    #
    # @return [Object] The variable's value.
    def [](key)
      if @my_vars.include?(key)
        @my_vars[key]
      else
        @coa_vars.each do |coa_vars|
          if coa_vars.include?(key)
            @my_vars[key] = deep_dup(coa_vars[key])
            return @my_vars[key]
          end
        end
        nil
      end
    end

    # Assign a value to a variable.
    #
    # @param key [String, Symbol] The variable name.
    #
    # @param val [Object] The value to set.
    def []=(key, val)
      @my_vars[key] = val
    end

    # Check if the VarSet contains a variable.
    #
    # @param key [String, Symbol] The variable name.
    #
    # @return [Boolean] Whether the VarSet contains the variable.
    def include?(key)
      if @my_vars.include?(key)
        true
      else
        @coa_vars.find do |coa_vars|
          coa_vars.include?(key)
        end
      end
    end

    # Add or overwrite a set of variables.
    #
    # @param values [VarSet, Hash] New set of variables.
    #
    # @return [VarSet] Returns self.
    def append(values)
      coa!
      if values.is_a?(VarSet)
        values.send(:coa!)
        @coa_vars = values.instance_variable_get(:@coa_vars) + @coa_vars
      else
        @my_vars = deep_dup(values)
      end
      self
    end

    # Create a new VarSet object based on the first merged with other.
    #
    # @param other [VarSet, Hash] Other variables to add or overwrite.
    #
    # @return [VarSet] The newly created VarSet.
    def merge(other = {})
      coa!
      varset = self.class.new
      varset.instance_variable_set(:@coa_vars, @coa_vars.dup)
      varset.append(other)
    end
    alias_method :clone, :merge

    # Replace "$!{var}" variable references in varref with the expanded
    # variables' values, recursively.
    #
    # @param varref [nil, String, Array, Proc, Symbol, TrueClass, FalseClass]
    #   Value containing references to variables.
    # @param lambda_args [Array]
    #   Arguments to pass to any lambda variable values to be expanded.
    #
    # @return [nil, String, Array, Symbol, TrueClass, FalseClass]
    #   Expanded value with "$!{var}" variable references replaced.
    def expand_varref(varref, lambda_args)
      case varref
      when Symbol, true, false, nil
        varref
      when String
        if varref =~ /^(.*)\$\{([^}]+)\}(.*)$/
          prefix, varname, suffix = $1, $2, $3
          prefix = expand_varref(prefix, lambda_args) unless prefix.empty?
          varval = expand_varref(self[varname], lambda_args)
          # suffix needs no expansion since the regex matches the last occurence
          case varval
          when Symbol, true, false, nil, String
            if prefix.is_a?(Array)
              prefix.map {|p| "#{p}#{varval}#{suffix}"}
            else
              "#{prefix}#{varval}#{suffix}"
            end
          when Array
            if prefix.is_a?(Array)
              varval.map {|vv| prefix.map {|p| "#{p}#{vv}#{suffix}"}}.flatten
            else
              varval.map {|vv| "#{prefix}#{vv}#{suffix}"}
            end
          else
            raise "Unknown construction variable type: #{varval.class} (from #{varname.inspect} => #{self[varname].inspect})"
          end
        else
          varref
        end
      when Array
        varref.map do |ent|
          expand_varref(ent, lambda_args)
        end.flatten
      when Proc
        expand_varref(varref[*lambda_args], lambda_args)
      else
        raise "Unknown construction variable type: #{varref.class} (#{varref.inspect})"
      end
    end

    # Return a Hash containing all variables in the VarSet.
    #
    # @since 1.8.0
    #
    # This method is not terribly efficient. It is intended to be used only by
    # debugging code to dump out a VarSet's variables.
    #
    # @return [Hash] All variables in the VarSet.
    def to_h
      result = deep_dup(@my_vars)
      @coa_vars.reduce(result) do |result, coa_vars|
        coa_vars.each_pair do |key, value|
          unless result.include?(key)
            result[key] = deep_dup(value)
          end
        end
        result
      end
    end

    # Return a String representing the VarSet.
    #
    # @return [String] Representation of the VarSet.
    def inspect
      to_h.inspect
    end

    # Return an array containing the values associated with the given keys.
    #
    # @param keys [Array<String, Symbol>]
    #   Keys to look up in the VarSet.
    #
    # @return [Array]
    #   An array containing the values associated with the given keys.
    def values_at(*keys)
      keys.map do |key|
        self[key]
      end
    end

    private

    # Move all VarSet variables into the copy-on-access list.
    #
    # @return [void]
    def coa!
      unless @my_vars.empty?
        @coa_vars.unshift(@my_vars)
        @my_vars = {}
      end
    end

    # Create a deep copy of an object.
    #
    # Only objects which are of type String, Array, or Hash are deep copied.
    # Any other object just has its referenced copied.
    #
    # @param obj [Object] Object to deep copy.
    #
    # @return [Object] Deep copied value.
    def deep_dup(obj)
      obj_class = obj.class
      if obj_class == Hash
        obj.reduce({}) do |result, (k, v)|
          result[k] = deep_dup(v)
          result
        end
      elsif obj_class == Array
        obj.map { |v| deep_dup(v) }
      elsif obj_class == String
        obj.dup
      else
        obj
      end
    end
  end
end
