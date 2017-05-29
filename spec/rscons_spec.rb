describe Rscons do
  describe ".clean" do
    it "removes all build targets and created directories" do
      cache = "cache"
      expect(Rscons::Cache).to receive(:instance).and_return(cache)
      expect(cache).to receive(:targets).and_return(["build/a.out", "build/main.o"])
      expect(FileUtils).to receive(:rm_f).with("build/a.out")
      expect(FileUtils).to receive(:rm_f).with("build/main.o")
      expect(cache).to receive(:directories).and_return(["build/one", "build/one/two", "build", "other"])
      expect(File).to receive(:directory?).with("build/one/two").and_return(true)
      expect(Dir).to receive(:entries).with("build/one/two").and_return([".", ".."])
      expect(Dir).to receive(:rmdir).with("build/one/two")
      expect(File).to receive(:directory?).with("build/one").and_return(true)
      expect(Dir).to receive(:entries).with("build/one").and_return([".", ".."])
      expect(Dir).to receive(:rmdir).with("build/one")
      expect(File).to receive(:directory?).with("build").and_return(true)
      expect(Dir).to receive(:entries).with("build").and_return([".", ".."])
      expect(Dir).to receive(:rmdir).with("build")
      expect(File).to receive(:directory?).with("other").and_return(true)
      expect(Dir).to receive(:entries).with("other").and_return([".", "..", "other.file"])
      expect(cache).to receive(:clear)

      Rscons.clean
    end
  end

  describe ".absolute_path?" do
    context "on Windows" do
      it "returns whether a path is absolute" do
        stub_const("RUBY_PLATFORM", "mingw")
        expect(Rscons.absolute_path?("/foo")).to be_truthy
        expect(Rscons.absolute_path?("\\Windows")).to be_truthy
        expect(Rscons.absolute_path?("C:\\Windows")).to be_truthy
        expect(Rscons.absolute_path?("f:\\stuff")).to be_truthy
        expect(Rscons.absolute_path?("g:/projects")).to be_truthy
        expect(Rscons.absolute_path?("x:foo")).to be_falsey
        expect(Rscons.absolute_path?("file.txt")).to be_falsey
      end
    end

    context "not on Windows" do
      it "returns whether a path is absolute" do
        stub_const("RUBY_PLATFORM", "linux")
        expect(Rscons.absolute_path?("/foo")).to be_truthy
        expect(Rscons.absolute_path?("\\Windows")).to be_falsey
        expect(Rscons.absolute_path?("C:\\Windows")).to be_falsey
        expect(Rscons.absolute_path?("f:\\stuff")).to be_falsey
        expect(Rscons.absolute_path?("g:/projects")).to be_falsey
        expect(Rscons.absolute_path?("x:foo")).to be_falsey
        expect(Rscons.absolute_path?("file.txt")).to be_falsey
      end
    end
  end

  describe ".set_suffix" do
    it "changes the suffix to the new one" do
      expect(Rscons.set_suffix("foo.c", ".h")).to eq("foo.h")
    end

    it "appends a suffix if the given file name does not have one" do
      expect(Rscons.set_suffix("bazz", ".d")).to eq("bazz.d")
    end
  end

  describe ".get_system_shell" do
    before(:each) do
      Rscons.instance_variable_set(:@shell, nil)
    end

    after(:each) do
      Rscons.instance_variable_set(:@shell, nil)
    end

    it "uses the SHELL environment variable if it tests successfully" do
      my_ENV = {"SHELL" => "my_shell"}
      allow(ENV).to receive(:[]) {|*args| my_ENV[*args]}
      io = StringIO.new("success\n")
      expect(IO).to receive(:popen).with(["my_shell", "-c", "echo success"]).and_yield(io)
      expect(Rscons.get_system_shell).to eq(["my_shell", "-c"])
    end

    it "uses sh -c on a mingw platform if it tests successfully" do
      my_ENV = {"SHELL" => nil}
      allow(ENV).to receive(:[]) {|*args| my_ENV[*args]}
      io = StringIO.new("success\n")
      expect(IO).to receive(:popen).with(["sh", "-c", "echo success"]).and_yield(io)
      expect(Object).to receive(:const_get).with("RUBY_PLATFORM").and_return("x86-mingw")
      expect(Rscons.get_system_shell).to eq(["sh", "-c"])
    end

    it "uses cmd /c on a mingw platform if sh -c does not test successfully" do
      my_ENV = {"SHELL" => nil}
      allow(ENV).to receive(:[]) {|*args| my_ENV[*args]}
      io = StringIO.new("success\n")
      expect(IO).to receive(:popen).with(["sh", "-c", "echo success"]).and_raise "ENOENT"
      expect(Object).to receive(:const_get).with("RUBY_PLATFORM").and_return("x86-mingw")
      expect(Rscons.get_system_shell).to eq(["cmd", "/c"])
    end

    it "uses sh -c on a non-mingw platform if SHELL is not specified" do
      my_ENV = {"SHELL" => nil}
      allow(ENV).to receive(:[]) {|*args| my_ENV[*args]}
      expect(Object).to receive(:const_get).with("RUBY_PLATFORM").and_return("x86-linux")
      expect(Rscons.get_system_shell).to eq(["sh", "-c"])
    end
  end

  context "command executer" do
    describe ".command_executer" do
      before(:each) do
        Rscons.instance_variable_set(:@command_executer, nil)
      end

      after(:each) do
        Rscons.instance_variable_set(:@command_executer, nil)
      end

      it "returns ['env'] if mingw platform in MSYS and 'env' works" do
        expect(Object).to receive(:const_get).and_return("x86-mingw")
        expect(ENV).to receive(:keys).and_return(["MSYSCON"])
        io = StringIO.new("success\n")
        expect(IO).to receive(:popen).with(["env", "echo", "success"]).and_yield(io)
        expect(Rscons.command_executer).to eq(["env"])
      end

      it "returns [] if mingw platform in MSYS and 'env' does not work" do
        expect(Object).to receive(:const_get).and_return("x86-mingw")
        expect(ENV).to receive(:keys).and_return(["MSYSCON"])
        expect(IO).to receive(:popen).with(["env", "echo", "success"]).and_raise "ENOENT"
        expect(Rscons.command_executer).to eq([])
      end

      it "returns [] if mingw platform not in MSYS" do
        expect(Object).to receive(:const_get).and_return("x86-mingw")
        expect(ENV).to receive(:keys).and_return(["COMSPEC"])
        expect(Rscons.command_executer).to eq([])
      end

      it "returns [] if not mingw platform" do
        expect(Object).to receive(:const_get).and_return("x86-linux")
        expect(Rscons.command_executer).to eq([])
      end
    end

    describe ".command_executer=" do
      it "overrides the value of @command_executer" do
        Rscons.instance_variable_set(:@command_executer, ["env"])
        Rscons.command_executer = []
        expect(Rscons.instance_variable_get(:@command_executer)).to eq([])
      end
    end
  end

  describe ".determine_n_threads" do
    context "when specified by environment variable" do
      before(:each) do
        expect(ENV).to receive(:[]).with("RSCONS_NTHREADS").and_return("3")
      end
      it "returns the user-specified number of threads to use" do
        expect(Rscons.__send__(:determine_n_threads)).to eq(3)
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
          expect(Rscons.__send__(:determine_n_threads)).to eq(2)
        end
      end

      context "on Windows" do
        before(:each) do
          expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("mingw")
        end
        it "returns the number of logical processors that wmic reports" do
          expect(Rscons).to receive(:`).with("wmic cpu get NumberOfLogicalProcessors /value").and_return("NumberOfLogicalProcessors=7")
          expect(Rscons.__send__(:determine_n_threads)).to eq(7)
        end
      end

      context "on Darwin" do
        before(:each) do
          expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("darwin")
        end
        it "returns the number of threads that sysctl reports" do
          expect(Rscons).to receive(:`).with("sysctl -n hw.ncpu").and_return("6")
          expect(Rscons.__send__(:determine_n_threads)).to eq(6)
        end
      end

      context "on an unknown platform" do
        before(:each) do
          expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("other")
        end
        it "returns 1" do
          expect(Rscons.__send__(:determine_n_threads)).to eq(1)
        end
      end

      context "when an error occurs" do
        it "returns 1" do
          expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_raise("foo")
          expect(Rscons.__send__(:determine_n_threads)).to eq(1)
        end
      end
    end
  end
end
