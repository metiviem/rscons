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
      Rscons.class_variable_set(:@@shell, nil)
    end

    after(:each) do
      Rscons.class_variable_set(:@@shell, nil)
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
        Rscons.class_variable_set(:@@command_executer, nil)
      end

      after(:each) do
        Rscons.class_variable_set(:@@command_executer, nil)
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
      it "overrides the value of @@command_executer" do
        Rscons.class_variable_set(:@@command_executer, ["env"])
        Rscons.command_executer = []
        expect(Rscons.class_variable_get(:@@command_executer)).to eq([])
      end
    end
  end
end
