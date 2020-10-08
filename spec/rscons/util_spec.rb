module Rscons
  describe Util do

    describe ".absolute_path?" do
      context "on Windows" do
        it "returns whether a path is absolute" do
          stub_const("RUBY_PLATFORM", "mingw")
          expect(Util.absolute_path?("/foo")).to be_truthy
          expect(Util.absolute_path?("\\Windows")).to be_truthy
          expect(Util.absolute_path?("C:\\Windows")).to be_truthy
          expect(Util.absolute_path?("f:\\stuff")).to be_truthy
          expect(Util.absolute_path?("g:/projects")).to be_truthy
          expect(Util.absolute_path?("x:foo")).to be_falsey
          expect(Util.absolute_path?("file.txt")).to be_falsey
        end
      end

      context "on non-Windows" do
        it "returns whether a path is absolute" do
          stub_const("RUBY_PLATFORM", "linux")
          expect(Util.absolute_path?("/foo")).to be_truthy
          expect(Util.absolute_path?("\\Windows")).to be_falsey
          expect(Util.absolute_path?("C:\\Windows")).to be_falsey
          expect(Util.absolute_path?("f:\\stuff")).to be_falsey
          expect(Util.absolute_path?("g:/projects")).to be_falsey
          expect(Util.absolute_path?("x:foo")).to be_falsey
          expect(Util.absolute_path?("file.txt")).to be_falsey
        end
      end
    end

    describe ".colorize_markup" do
      it "turns a builder message string with markup into an Array for Ansi module" do
        expect(Util.colorize_markup("[ 1/33] Generating <foo> lexer from <source>parser/lexer.l<reset> => <target>build/e.1/parser/lexer.cc<reset>")).to eq ["[ 1/33] Generating ", "<foo>", " lexer from ", :cyan, "parser/lexer.l", :reset, " => ", :magenta, "build/e.1/parser/lexer.cc", :reset]
      end
    end

    describe ".determine_n_threads" do
      context "when specified by environment variable" do
        before(:each) do
          expect(ENV).to receive(:[]).with("RSCONS_NTHREADS").and_return("3")
        end
        it "returns the user-specified number of threads to use" do
          expect(Util.determine_n_threads).to eq(3)
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
            expect(Util.determine_n_threads).to eq(2)
          end
        end

        context "on Windows" do
          before(:each) do
            expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("mingw")
          end
          it "returns the number of logical processors that wmic reports" do
            expect(Util).to receive(:`).with("wmic cpu get NumberOfLogicalProcessors -value").and_return("NumberOfLogicalProcessors=7")
            expect(Util.determine_n_threads).to eq(7)
          end
        end

        context "on Darwin" do
          before(:each) do
            expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("darwin")
          end
          it "returns the number of threads that sysctl reports" do
            expect(Util).to receive(:`).with("sysctl -n hw.ncpu").and_return("6")
            expect(Util.determine_n_threads).to eq(6)
          end
        end

        context "on an unknown platform" do
          before(:each) do
            expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("other")
          end
          it "returns 1" do
            expect(Util.determine_n_threads).to eq(1)
          end
        end

        context "when an error occurs" do
          it "returns 1" do
            expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_raise("foo")
            expect(Util.determine_n_threads).to eq(1)
          end
        end
      end
    end

    describe ".find_executable" do
      context "when given a path with directory components" do
        it "returns the path if it is executable" do
          expect(File).to receive(:file?).with("a/path").and_return(true)
          expect(File).to receive(:executable?).with("a/path").and_return(true)
          expect(Util.find_executable("a/path")).to eq "a/path"
        end

        it "returns nil if the path is not executable" do
          expect(File).to receive(:file?).with("a/path").and_return(true)
          expect(File).to receive(:executable?).with("a/path").and_return(false)
          expect(Util.find_executable("a/path")).to be_nil
        end
      end

      context "when given a program name without directory components" do
        context "on Windows" do
          before(:each) do
            stub_const("File::PATH_SEPARATOR", ";")
            stub_const("RbConfig::CONFIG", "host_os" => "mingw")
            expect(ENV).to receive(:[]).with("PATH").and_return("C:\\none;C:\\bin;C:\\Windows")
            allow(File).to receive(:directory?).with("C:\\none").and_return(false)
            allow(File).to receive(:directory?).with("C:\\bin").and_return(true)
            allow(File).to receive(:directory?).with("C:\\Windows").and_return(true)
            allow(Dir).to receive(:entries).with("C:\\bin").and_return(%w[one.com])
            allow(Dir).to receive(:entries).with("C:\\Windows").and_return(%w[two.exe Three.bat])
          end

          it "returns a path to a .exe found" do
            expect(File).to receive(:file?).with("C:\\Windows/two.exe").and_return(true)
            expect(File).to receive(:executable?).with("C:\\Windows/two.exe").and_return(true)
            expect(Util.find_executable("two")).to eq "C:\\Windows/two.exe"
          end

          it "returns a path to a .exe found including extension" do
            expect(File).to receive(:file?).with("C:\\Windows/two.exe").and_return(true)
            expect(File).to receive(:executable?).with("C:\\Windows/two.exe").and_return(true)
            expect(Util.find_executable("TWO.EXE")).to eq "C:\\Windows/two.exe"
          end

          it "returns a path to a .com found" do
            expect(File).to receive(:file?).with("C:\\bin/one.com").and_return(true)
            expect(File).to receive(:executable?).with("C:\\bin/one.com").and_return(true)
            expect(Util.find_executable("ONE")).to eq "C:\\bin/one.com"
          end

          it "returns a path to a .bat found" do
            expect(File).to receive(:file?).with("C:\\Windows/Three.bat").and_return(true)
            expect(File).to receive(:executable?).with("C:\\Windows/Three.bat").and_return(true)
            expect(Util.find_executable("three")).to eq "C:\\Windows/Three.bat"
          end

          it "returns nil when nothing is found" do
            expect(Util.find_executable("notthere")).to be_nil
          end
        end
      end
    end

    describe ".format_elapsed_time" do
      it "includes minutes when hours is nonzero and minutes is zero" do
        expect(Util.format_elapsed_time(60 * 60 + 4)).to eq "1h 0m 4s"
      end

      it "only includes minutes and seconds when hours is zero and minutes is nonzero" do
        expect(Util.format_elapsed_time(3 * 60 + 33)).to eq "3m 33s"
      end

      it "only includes seconds when hours and minutes are zero" do
        expect(Util.format_elapsed_time(7.84)).to eq "8s"
      end
    end

    describe ".make_relative_path" do
      context "when passed a relative path" do
        it "returns the path itself" do
          expect(Util.make_relative_path("foo/bar")).to eq "foo/bar"
        end
      end

      context "when passed an absolute path" do
        before(:each) do
          expect(Util).to receive(:absolute_path?).and_return(true)
        end

        context "on Windows" do
          it "returns a relative path corresponding to an absolute one" do
            expect(Util.make_relative_path("D:/foo/bar")).to eq "_D/foo/bar"
          end
        end

        context "on non-Windows" do
          it "returns a relative path corresponding to an absolute one" do
            expect(Util.make_relative_path("/foo/bar")).to eq "_/foo/bar"
          end
        end
      end
    end

    describe ".parse_dependency_file" do
      it 'handles dependencies on one line' do
        expect(File).to receive(:read).with('makefile').and_return(<<EOS)
module.o: source.cc
EOS
        expect(Util.parse_dependency_file('makefile')).to eq ['source.cc']
      end

      it 'handles dependencies split across many lines' do
        expect(File).to receive(:read).with('makefile').and_return(<<EOS)
module.o: module.c \\
  module.h \\
  other.h
EOS
        expect(Util.parse_dependency_file('makefile')).to eq [
          'module.c', 'module.h', 'other.h']
      end

      it "parses ldc2-style dependency lines" do
        expect(File).to receive(:read).with("deps.out").and_return(<<EOS)
std.traits (/usr/lib/ldc/x86_64-linux-gnu/include/d/std/traits.d) : private : std.meta (/usr/lib/ldc/x86_64-linux-gnu/include/d/std/meta.d):staticIndexOf
std.conv (/usr/lib/ldc/x86_64-linux-gnu/include/d/std/conv.d) : private : std.array (/usr/lib/ldc/x86_64-linux-gnu/include/d/std/array.d):array
std.stdio (/usr/lib/ldc/x86_64-linux-gnu/include/d/std/stdio.d) : private static : core.sys.posix.sys.socket (/usr/lib/ldc/x86_64-linux-gnu/include/d/core/sys/posix/sys/socket.d) -> sock
EOS
        expect(Util.parse_dependency_file("deps.out")).to eq [
          "/usr/lib/ldc/x86_64-linux-gnu/include/d/std/meta.d",
          "/usr/lib/ldc/x86_64-linux-gnu/include/d/std/array.d",
          "/usr/lib/ldc/x86_64-linux-gnu/include/d/core/sys/posix/sys/socket.d",
        ]
      end
    end

  end
end
