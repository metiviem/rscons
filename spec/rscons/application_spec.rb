module Rscons
  describe Application do

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

        Rscons.application.__send__(:clean)
      end
    end

  end
end
