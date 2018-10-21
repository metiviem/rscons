module Rscons
  # Module to contain logic to write ANSI color escape codes.
  module Ansi
    class << self

      # Write a message to an IO with ANSI escape codes.
      #
      # @param io [IO]
      #   The IO to write to.
      # @param message [Array<String, Symbol>]
      #   Strings to be printed, with Symbols representing ANSI escape codes.
      #
      # @return [void]
      def write(io, *message)
        do_color = Rscons.application.do_ansi_color
        if do_color.nil?
          do_color = do_ansi?(io)
        end
        out = ""
        message.each do |m|
          if m.is_a?(String)
            out += m
          elsif do_color
            case m
            when :red
              out += "\e[0;31m"
            when :cyan
              out += "\e[0;36m"
            when :reset
              out += "\e[0m"
            end
          end
        end
        io.write(out)
      end

      private

      # Determine whether to output ANSI color escape codes.
      #
      # @return [Boolean]
      #   Whether to output ANSI color escape codes.
      def do_ansi?(io)
        if RUBY_PLATFORM =~ /mingw/
          (ENV["TERM"] == "xterm") && %w[fifo characterSpecial].include?(io.stat.ftype)
        else
          io.tty?
        end
      end

    end
  end
end
