module Rscons
  module Builders
    describe Object do
      let(:env) {Environment.new}
      let(:cache) {double(Cache)}
      subject {Object.new}

      it "supports overriding CCCMD construction variable" do
        expect(cache).to receive(:up_to_date?).and_return(false)
        expect(cache).to receive(:mkdir_p)
        expect(FileUtils).to receive(:rm_f)
        expect(env).to receive(:execute).with("CC mod.o", ["llc", "mod.c"]).and_return(true)
        expect(File).to receive(:exists?).and_return(false)
        expect(cache).to receive(:register_build)

        subject.run(
          target: "mod.o",
          sources: ["mod.c"],
          cache: cache,
          env: env,
          vars: {"CCCMD" => ["llc", "${_SOURCES}"]})
      end

      it "supports overriding DEPFILESUFFIX construction variable" do
        expect(cache).to receive(:up_to_date?).and_return(false)
        expect(cache).to receive(:mkdir_p)
        expect(FileUtils).to receive(:rm_f)
        expect(env).to receive(:execute).with(anything, %w[gcc -c -o f.o -MMD -MF f.d in.c]).and_return(true)
        expect(File).to receive(:exists?).with("f.d").and_return(false)
        expect(cache).to receive(:register_build)

        subject.run(
          target: "f.o",
          sources: ["in.c"],
          cache: cache,
          env: env,
          vars: {"DEPFILESUFFIX" => ".d"})
      end

      it "raises an error when given a source file with an unknown suffix" do
        expect do
          subject.run(
            target: "mod.o",
            sources: ["mod.xyz"],
            cache: :cache,
            env: env,
            vars: {})
        end.to raise_error /unknown input file type: "mod.xyz"/
      end
    end
  end
end
