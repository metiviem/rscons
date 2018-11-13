module Rscons
  describe Ansi do
    let(:io) {double}

    describe ".write" do
      context "when not doing color" do
        before(:each) do
          stub_const("RUBY_PLATFORM", "linux")
          allow(io).to receive(:tty?).and_return(false)
        end

        it "skips color attributes and just writes the String arguments" do
          expect(io).to receive(:write).with("line 1\nline 2\n")
          Ansi.write(io, :bold, "line ", :red, "1\nline ", :boldblue, "2", "\n")
        end
      end

      context "when doing color" do
        before(:each) do
          stub_const("RUBY_PLATFORM", "linux")
          allow(io).to receive(:tty?).and_return(true)
        end

        it "writes the expected ANSI escape codes" do
          expect(io).to receive(:write).with("\e[1mline \e[0;31m1\e[0m\n\e[0;31mline \e[1;34m2\e[0m\n")
          Ansi.write(io, :bold, "line ", :red, "1\nline ", :boldblue, "2", "\n")
        end

        it "ends with a reset sequence" do
          expect(io).to receive(:write).with("\e[1;33mbold yellow\e[0m")
          Ansi.write(io, :boldyellow, "bold yellow")
        end

        it "does not write a color sequence when it would be overwritten" do
          expect(io).to receive(:write).with("\e[1;36mBOLD CYAN\e[0m\n")
          Ansi.write(io, :boldyellow, :boldcyan, "BOLD CYAN\n")
        end

        it "uses the correct escape sequences for all colors" do
          expect(io).to receive(:write).with("\e[0;31mHI\e[0m")
          Ansi.write(io, :red, "HI")
          expect(io).to receive(:write).with("\e[0;32mHI\e[0m")
          Ansi.write(io, :green, "HI")
          expect(io).to receive(:write).with("\e[0;33mHI\e[0m")
          Ansi.write(io, :yellow, "HI")
          expect(io).to receive(:write).with("\e[0;34mHI\e[0m")
          Ansi.write(io, :blue, "HI")
          expect(io).to receive(:write).with("\e[0;35mHI\e[0m")
          Ansi.write(io, :magenta, "HI")
          expect(io).to receive(:write).with("\e[0;36mHI\e[0m")
          Ansi.write(io, :cyan, "HI")
          expect(io).to receive(:write).with("\e[0;37mHI\e[0m")
          Ansi.write(io, :white, "HI")
          expect(io).to receive(:write).with("\e[1;31mHI\e[0m")
          Ansi.write(io, :boldred, "HI")
          expect(io).to receive(:write).with("\e[1;32mHI\e[0m")
          Ansi.write(io, :boldgreen, "HI")
          expect(io).to receive(:write).with("\e[1;33mHI\e[0m")
          Ansi.write(io, :boldyellow, "HI")
          expect(io).to receive(:write).with("\e[1;34mHI\e[0m")
          Ansi.write(io, :boldblue, "HI")
          expect(io).to receive(:write).with("\e[1;35mHI\e[0m")
          Ansi.write(io, :boldmagenta, "HI")
          expect(io).to receive(:write).with("\e[1;36mHI\e[0m")
          Ansi.write(io, :boldcyan, "HI")
          expect(io).to receive(:write).with("\e[1;37mHI\e[0m")
          Ansi.write(io, :boldwhite, "HI")
        end
      end
    end

    describe ".do_ansi?" do
      context "on Windows" do
        it "returns true when IO is a fifo on an xterm" do
          stub_const("RUBY_PLATFORM", "mingw")
          expect(ENV).to receive(:[]).with("TERM").and_return("xterm")
          expect(io).to receive(:stat).and_return(Struct.new(:ftype).new("fifo"))
          expect(Ansi.__send__(:do_ansi?, io)).to be_truthy
        end

        it "returns false when TERM is not set appropriately" do
          stub_const("RUBY_PLATFORM", "mingw")
          expect(ENV).to receive(:[]).with("TERM").and_return(nil)
          expect(Ansi.__send__(:do_ansi?, io)).to be_falsey
        end
      end

      context "on POSIX" do
        it "returns true when IO is a TTY" do
          stub_const("RUBY_PLATFORM", "linux")
          expect(io).to receive(:tty?).and_return(true)
          expect(Ansi.__send__(:do_ansi?, io)).to be_truthy
        end
      end
    end

  end
end
