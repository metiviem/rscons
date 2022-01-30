module Rscons

  # A task is a named collection of actions and/or dependencies.
  class Task

    class << self

      # Access a task by name.
      #
      # @param name [String, nil]
      #   Task name, or nil to return a Hash of all tasks.
      #
      # @return [Hash, Task, nil]
      #   Hash of all tasks if name is nil, otherwise Task with the given name,
      #   if found.
      def [](name = nil)
        if name
          if task = tasks[name]
            task
          else
            raise RsconsError.new("Task '#{name}' not found")
          end
        else
          tasks
        end
      end

      # Register a newly created task.
      #
      # @api private
      #
      # @param task [Task]
      #   Task to register.
      #
      # @return [void]
      def register(task)
        tasks[task.name] = task
      end

      # Get all registered tasks.
      #
      # @api private
      #
      # @return [Hash]
      #   All registered tasks.
      def tasks
        @tasks ||= {}
      end

    end

    # Class to represent a task parameter.
    class Param

      # @return [String]
      #   Param name.
      attr_reader :name

      # @return [String]
      #   Param description.
      attr_reader :description

      # @return [Boolean]
      #   Whether the parameter takes an argument.
      attr_reader :takes_arg

      # @return [String, nil]
      #   Param value.
      attr_accessor :value

      # Construct a Param.
      #
      # @param name [String]
      #   Param name.
      # @param value [String, nil]
      #   Param value.
      # @param takes_arg [String]
      #   Whether the parameter takes an argument.
      # @param description [String]
      #   Param description.
      def initialize(name, value, takes_arg, description)
        @name = name
        @value = value
        @takes_arg = takes_arg
        @description = description
      end

    end

    # @return [Array<Proc>]
    #   Task action blocks.
    attr_reader :actions

    # @return [Boolean]
    #   Whether to automatically configure before running this task.
    attr_reader :autoconf

    # @return [Array<String>]
    #   Task dependencies.
    attr_reader :deps

    # @return [String, nil]
    #   Task description, if given.
    attr_reader :desc

    # @return [String]
    #   Task name.
    attr_reader :name

    # @return [Hash<String => Param>]
    #   Task params.
    attr_reader :params

    # Construct a task.
    #
    # @param name [String]
    #   Task name.
    # @param options [Hash]
    #   Options.
    # @option options [Boolean] :autoconf
    #   Whether to automatically configure before running this task (default
    #   true).
    def initialize(name, options, &block)
      @autoconf = true
      @deps = []
      @desc = nil
      @name = name
      @params = {}
      @actions = []
      Task.register(self)
      modify(options, &block)
    end

    # Get a parameter's value.
    #
    # @param param_name [String]
    #   Parameter name.
    #
    # @return [String]
    #   Parameter value.
    def [](param_name)
      param = @params[param_name]
      unless param
        raise RsconsError.new("Could not find parameter '#{param_name}'")
      end
      param.value
    end

    # Execute a task's actions.
    #
    # @return [void]
    def execute
      @executed = true
      if @autoconf
        Rscons.application.check_configure
      end
      @deps.each do |dep|
        Task[dep].check_execute
      end
      if @name == "configure"
        Rscons.application.configure
      else
        @actions.each do |action|
          action[self, param_values]
        end
      end
    end

    # Check if the task has been executed, and if not execute it.
    #
    # @return [void]
    def check_execute
      unless executed?
        execute
      end
    end

    # Check if the task has been executed.
    #
    # @return [Boolean]
    #   Whether the task has been executed.
    def executed?
      @executed
    end

    # Modify a task.
    #
    # @api private
    #
    # @return [void]
    def modify(options, &block)
      if options.include?(:autoconf)
        @autoconf = options[:autoconf]
      end
      if options.include?(:desc)
        @desc = options[:desc]
      end
      if options.include?(:deps)
        @deps += Array(options[:deps])
      end
      if options.include?(:params)
        Array(options[:params]).each do |param|
          @params[param.name] = param
        end
      end
      if block
        if env = Environment.open_environment
          @actions << proc do
            block[]
            env.process
          end
        else
          @actions << block
        end
      end
    end

    # Get parameter values as a Hash.
    #
    # @return [Hash]
    #   Parameter values.
    def param_values
      param_values = {}
      @params.each do |name, param|
        param_values[name] = param.value
      end
      param_values
    end

  end

end
