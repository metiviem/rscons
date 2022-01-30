require "rscons"
require "optparse"

module Rscons
  # Command-Line Interface functionality.
  class Cli

    # Default files to look for to execute if none specified.
    DEFAULT_RSCONSCRIPTS = %w[Rsconscript Rsconscript.rb]

    # Run the Rscons CLI.
    #
    # @param argv [Array]
    #   Command-line parameters.
    #
    # @return [void]
    def run(argv)
      argv = argv.dup
      begin
        exit run_toplevel(argv)
      rescue OptionParser::InvalidOption => io
        $stderr.puts io.message
        $stderr.puts usage
        exit 2
      end
    end

    private

    def parse_task_params(task, argv)
      while argv.size > 0
        if argv[0].start_with?("-")
          valid_arg = false
          if argv[0] =~ /^--(\S+?)(?:=(.*))?$/
            param_name, value = $1, $2
            if param = Task[task].params[param_name]
              param.value = value || argv[0]
              argv.slice!(0)
              valid_arg = true
            end
          end
          unless valid_arg
            $stderr.puts "Invalid task '#{task}' argument '#{argv[0].split("=").first}'"
            $stderr.puts usage
            exit 2
          end
        else
          return
        end
      end
    end

    def parse_tasks_and_params(argv)
      tasks = []
      while argv.size > 0
        task = argv.shift
        parse_task_params(task, argv)
        tasks << task
      end
      tasks
    end

    def run_toplevel(argv)
      rsconscript = nil
      do_help = false

      OptionParser.new do |opts|

        opts.on("-b", "--build DIR") do |build_dir|
          Rscons.application.build_dir = build_dir
        end

        opts.on("-f FILE") do |f|
          rsconscript = f
        end

        opts.on("-F", "--show-failure") do
          Rscons.application.show_failure
          return 0
        end

        opts.on("-h", "--help") do
          do_help = true
        end

        opts.on("-j NTHREADS") do |n_threads|
          Rscons.application.n_threads = n_threads.to_i
        end

        opts.on("-r", "--color MODE") do |color_mode|
          case color_mode
          when "off"
            Rscons.application.do_ansi_color = false
          when "force"
            Rscons.application.do_ansi_color = true
          end
        end

        opts.on("-v", "--verbose") do
          Rscons.application.verbose = true
        end

        opts.on("--version") do
          puts "Rscons version #{Rscons::VERSION}"
          return 0
        end

      end.order!(argv)

      # Find the build script.
      if rsconscript
        unless File.exists?(rsconscript)
          $stderr.puts "Cannot read #{rsconscript}"
          return 1
        end
      else
        rsconscript = DEFAULT_RSCONSCRIPTS.find do |f|
          File.exists?(f)
        end
      end

      begin
        # Load the build script.
        if rsconscript
          Rscons.application.script.load(rsconscript)
        end

        # Do help after loading the build script (if found) so that any
        # script-defined tasks and task options can be displayed.
        if do_help
          puts usage
          return 0
        end

        # Anything else requires a build script, so complain if we didn't find
        # one.
        unless rsconscript
          $stderr.puts "Could not find the Rsconscript to execute."
          $stderr.puts "Looked for: #{DEFAULT_RSCONSCRIPTS.join(", ")}"
          return 1
        end

        # Parse the rest of the command line. This is done after loading the
        # build script so that script-defined tasks and task options can be
        # taken into account.
        tasks = parse_tasks_and_params(argv)

        # If no user specified tasks, run "default" task.
        if tasks.empty?
          tasks << "default"
        end

        # Finally, with the script fully loaded and command-line parsed, run
        # the application to execute all required tasks.
        Rscons.application.run(tasks)
      rescue RsconsError => e
        Ansi.write($stderr, :red, e.message, :reset, "\n")
        1
      end
    end

    def usage
      usage = <<EOF
Usage: #{$0} [global options] [[task] [task options] ...]

Global options:
  -b BUILD, --build=BUILD     Set build directory (default: build)
  -f FILE                     Use FILE as Rsconscript
  -F, --show-failure          Show failed command log from previous build and exit
  -h, --help                  Show rscons help and exit
  -j N, --nthreads=N          Set number of threads (local default: #{Rscons.application.n_threads})
  -r COLOR, --color=COLOR     Set color mode (off, auto, force)
  -v, --verbose               Run verbosely
  --version                   Show rscons version and exit

Tasks:
EOF
      Task[].each do |name, task|
        if task.desc
          usage += %[  #{sprintf("%-27s", name)} #{task.desc}\n]
          task.params.each do |name, param|
            arg_text = "--#{name}"
            if param.takes_arg
              arg_text += "=#{name.upcase}"
            end
            usage += %[    #{sprintf("%-25s", "#{arg_text}")} #{param.description}\n]
          end
        end
      end
      usage
    end

  end
end
