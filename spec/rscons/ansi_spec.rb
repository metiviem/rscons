module Rscons
  describe Ansi do
    describe ".do_ansi?" do

      context "on Windows" do
        it "returns true when IO is a fifo on an xterm" do
          stub_const("RUBY_PLATFORM", "mingw")
          expect(ENV).to receive(:[]).with("TERM").and_return("xterm")
          io = double
          expect(io).to receive(:stat).and_return(Struct.new(:ftype).new("fifo"))
          expect(Ansi.__send__(:do_ansi?, io)).to be_truthy
        end

        it "returns false when TERM is not set appropriately" do
          stub_const("RUBY_PLATFORM", "mingw")
          expect(ENV).to receive(:[]).with("TERM").and_return(nil)
          io = double
          expect(Ansi.__send__(:do_ansi?, io)).to be_falsey
        end
      end

      context "on POSIX" do
        it "returns true when IO is a TTY" do
          stub_const("RUBY_PLATFORM", "linux")
          io = double
          expect(io).to receive(:tty?).and_return(true)
          expect(Ansi.__send__(:do_ansi?, io)).to be_truthy
        end
      end

    end
  end
end
