module Rscons
  describe Application do

    describe ".determine_n_threads" do
      context "when specified by environment variable" do
        before(:each) do
          expect(ENV).to receive(:[]).with("RSCONS_NTHREADS").and_return("3")
        end
        it "returns the user-specified number of threads to use" do
          expect(Rscons.application.__send__(:determine_n_threads)).to eq(3)
        end
      end

      context "when not specified by environment variable" do
        before(:each) do
          expect(ENV).to receive(:[]).with("RSCONS_NTHREADS").and_return(nil)
        end

        context "on Linux" do
          before(:each) do
            expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("linux")
          end
          it "returns the number of processors from /proc/cpuinfo" do
            expect(File).to receive(:read).with("/proc/cpuinfo").and_return(<<EOF)
processor : 0
processor   : 1
EOF
            expect(Rscons.application.__send__(:determine_n_threads)).to eq(2)
          end
        end

        context "on Windows" do
          before(:each) do
            expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("mingw")
          end
          it "returns the number of logical processors that wmic reports" do
            expect(Rscons).to receive(:`).with("wmic cpu get NumberOfLogicalProcessors /value").and_return("NumberOfLogicalProcessors=7")
            expect(Rscons.application.__send__(:determine_n_threads)).to eq(7)
          end
        end

        context "on Darwin" do
          before(:each) do
            expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("darwin")
          end
          it "returns the number of threads that sysctl reports" do
            expect(Rscons).to receive(:`).with("sysctl -n hw.ncpu").and_return("6")
            expect(Rscons.application.__send__(:determine_n_threads)).to eq(6)
          end
        end

        context "on an unknown platform" do
          before(:each) do
            expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("other")
          end
          it "returns 1" do
            expect(Rscons.application.__send__(:determine_n_threads)).to eq(1)
          end
        end

        context "when an error occurs" do
          it "returns 1" do
            expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_raise("foo")
            expect(Rscons.application.__send__(:determine_n_threads)).to eq(1)
          end
        end
      end
    end

  end
end
