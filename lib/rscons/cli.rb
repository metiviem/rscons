require "rscons"
require "optparse"

USAGE = <<EOF
Usage: #{$0} [global options] [operation] [operation options]

Global options:
  --version                   Show rscons version and exit
  -h, --help                  Show rscons help and exit
  -r COLOR, --color=COLOR     Set color mode (off, auto, force)

Operations:
  configure                   Configure the project
  build                       Build the project
  clean                       Remove build artifacts (but not configuration)
  distclean                   Remove build directory and configuration
  install                     Install project to installation destination
  uninstall                   Uninstall project from installation destination

Configure options:
  -b BUILD, --build=BUILD     Set build directory (default: build)
  --prefix=PREFIX             Set installation prefix (default: /usr/local)

Build options:
  -j N, --nthreads=N          Set number of threads (local default: #{Rscons.n_threads})

EOF

module Rscons
  # Command-Line Interface functionality.
  module Cli

    # Default files to look for to execute if none specified.
    DEFAULT_RSCONSFILES = %w[Rsconsfile Rsconsfile.rb]

    class << self

      # Run the Rscons CLI.
      #
      # @param argv [Array]
      #   Command-line parameters.
      #
      # @return [void]
      def run(argv)
        argv = argv.dup
        rsconsfile = nil

        OptionParser.new do |opts|
          opts.banner = "Usage: #{$0} [options]"

          opts.separator ""
          opts.separator "Options:"

          opts.on("-f FILE", "Execute FILE (default Rsconsfile)") do |f|
            rsconsfile = f
          end

          opts.on("-j NTHREADS", "Use NTHREADS parallel jobs (local default #{Rscons.n_threads})") do |n_threads|
            Rscons.n_threads = n_threads.to_i
          end

          opts.on("-r", "--color MODE", "Set color mode (off, auto, force)") do |color_mode|
            case color_mode
            when "off"
              Rscons.do_ansi_color = false
            when "force"
              Rscons.do_ansi_color = true
            end
          end

          opts.on("--version", "Show version") do
            puts "Rscons version #{Rscons::VERSION}"
            exit 0
          end

          opts.on("-h", "--help", "Show this help.") do
            puts USAGE
            exit 0
          end

        end.order!(argv)

        if argv.empty?
          puts USAGE
          exit 0
        end

        case argv.first
        when "clean"
          Rscons.clean
          exit 0
        when "configure"
          # TODO
          exit 0
        end

        argv.each do |arg|
          if arg =~ /^([^=]+)=(.*)$/
            Rscons.vars[$1] = $2
          end
        end

        if rsconsfile
          unless File.exists?(rsconsfile)
            $stderr.puts "Cannot read #{rsconsfile}"
            exit 1
          end
        else
          rsconsfile = DEFAULT_RSCONSFILES.find do |f|
            File.exists?(f)
          end
          unless rsconsfile
            $stderr.puts "Could not find the Rsconsfile to execute."
            $stderr.puts "Looked for: #{DEFAULT_RSCONSFILES.join(", ")}"
            exit 1
          end
        end

        begin
          load rsconsfile
        rescue Rscons::BuildError => e
          exit 1
        end

        exit 0
      end

    end
  end
end
