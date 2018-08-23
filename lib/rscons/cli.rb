require "rscons"
require "optparse"

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

          opts.on("-c", "--clean", "Perform clean operation") do
            Rscons.clean
            exit 0
          end

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

          opts.on_tail("--version", "Show version") do
            puts "Rscons version #{Rscons::VERSION}"
            exit 0
          end

          opts.on_tail("-h", "--help", "Show this help.") do
            puts opts
            exit 0
          end

        end.parse!(argv)

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
            $stderr.puts "Looked in: [#{DEFAULT_RSCONSFILES.join(", ")}]"
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
