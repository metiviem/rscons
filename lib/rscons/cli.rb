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
      task_params = {}
      while argv.size > 0
        if argv[0] =~ /^--(\S+?)(?:=(.*))?$/
          param_name, param_value = $1, $2
          param_value ||= true
          task_params[param_name] = param_value
          argv.slice!(0)
        else
          break
        end
      end
      task_params
    end

    def parse_tasks_and_params(argv)
      tasks_and_params = {}
      while argv.size > 0
        task = argv.shift
        tasks_and_params[task] = parse_task_params(task, argv)
      end
      tasks_and_params
    end

    def run_toplevel(argv)
      rsconscript = nil
      show_tasks = false
      all_tasks = false
      enabled_variants = ""

      OptionParser.new do |opts|

        opts.on("-A", "--all") do
          all_tasks = true
        end

        opts.on("-b", "--build DIR") do |build_dir|
          Rscons.application.build_dir = build_dir
        end

        opts.on("-e", "--variants VS") do |variants|
          enabled_variants = variants
        end

        opts.on("-f FILE") do |f|
          rsconscript = f
        end

        opts.on("-F", "--show-failure") do
          Rscons.application.show_failure
          return 0
        end

        opts.on("-h", "--help") do
          puts usage
          return 0
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

        opts.on("-T", "--tasks") do
          show_tasks = true
        end

        opts.on("-v", "--verbose") do
          Rscons.application.verbose = true
        end

        opts.on("--version") do
          puts "Rscons version #{Rscons::VERSION}"
          return 0
        end

      end.order!(argv)

      # Parse the rest of the command line.
      tasks_and_params = parse_tasks_and_params(argv)

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

      # Anything else requires a build script, so complain if we didn't find
      # one.
      unless rsconscript
        $stderr.puts "Could not find the Rsconscript to execute."
        $stderr.puts "Looked for: #{DEFAULT_RSCONSCRIPTS.join(", ")}"
        return 1
      end

      begin
        Rscons.application.run(rsconscript, tasks_and_params, show_tasks, all_tasks, enabled_variants)
      rescue RsconsError => e
        Ansi.write($stderr, :red, e.message, :reset, "\n")
        1
      end
    end

    def usage
      <<EOF
Usage: #{$0} [global options] [[task] [task options] ...]

Global options:
  -A, --all                   Show all tasks (even without descriptions) in task list
  -b BUILD, --build=BUILD     Set build directory (default: build)
  -e VS, --variants=VS        Enable or disable variants
  -f FILE                     Use FILE as Rsconscript
  -F, --show-failure          Show failed command log from previous build and exit
  -h, --help                  Show rscons help and exit
  -j N, --nthreads=N          Set number of threads (local default: #{Rscons.application.n_threads})
  -r COLOR, --color=COLOR     Set color mode (off, auto, force)
  -T, --tasks                 Show task list and parameters and exit
  -v, --verbose               Run verbosely
  --version                   Show rscons version and exit
EOF
    end

  end
end
