module Rscons
  # Module to contain logic to write ANSI color escape codes.
  module Ansi
    class << self

      RESET = "\e[0m"

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
        if do_color
          current_color = RESET
          desired_color = RESET
          message.each do |m|
            if m.is_a?(String)
              lines = m.split("\n", -1)
              lines.each_with_index do |line, i|
                if line != ""
                  if current_color != desired_color
                    out += desired_color
                    current_color = desired_color
                  end
                  out += line
                end
                if i < lines.size - 1
                  # A newline follows
                  if current_color != RESET
                    out += RESET
                    current_color = RESET
                  end
                  out += "\n"
                end
              end
            else
              case m
              when :red;            desired_color = "\e[0;31m"
              when :green;          desired_color = "\e[0;32m"
              when :yellow;         desired_color = "\e[0;33m"
              when :blue;           desired_color = "\e[0;34m"
              when :magenta;        desired_color = "\e[0;35m"
              when :cyan;           desired_color = "\e[0;36m"
              when :white;          desired_color = "\e[0;37m"
              when :boldred;        desired_color = "\e[1;31m"
              when :boldgreen;      desired_color = "\e[1;32m"
              when :boldyellow;     desired_color = "\e[1;33m"
              when :boldblue;       desired_color = "\e[1;34m"
              when :boldmagenta;    desired_color = "\e[1;35m"
              when :boldcyan;       desired_color = "\e[1;36m"
              when :boldwhite;      desired_color = "\e[1;37m"
              when :bold;           desired_color = "\e[1m"
              when :reset;          desired_color = RESET
              end
            end
          end
          if current_color != RESET
            out += RESET
          end
        else
          message.each do |m|
            if m.is_a?(String)
              out += m
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
