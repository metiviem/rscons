module Rscons
  module Builders
    describe Preprocess do

      let(:env) {Environment.new}
      subject {Preprocess.new}

      it "supports overriding CC construction variable" do
        cache = double(Cache)
        command = %w[my_cpp -E -MMD -MF module.mf -o module.pp module.c]
        expect(cache).to receive(:up_to_date?).with("module.pp", command, %w[module.c], env).and_return(false)
        expect(cache).to receive(:mkdir_p).with(".")
        expect(env).to receive(:execute).with("Preprocess module.pp", command).and_return(true)
        expect(File).to receive(:exists?).with("module.mf").and_return(true)
        expect(Environment).to receive(:parse_makefile_deps).with("module.mf", nil).and_return(%w[module.c one.h two.h])
        expect(FileUtils).to receive(:rm_f).with("module.mf")
        expect(cache).to receive(:register_build).with("module.pp", command, %w[module.c one.h two.h], env)

        expect(subject.run("module.pp", ["module.c"], cache, env, "CC" => "my_cpp")).to eq("module.pp")
      end

      it "supports overriding CPP_CMD construction variable" do
        cache = double(Cache)
        command = %w[my_cpp module.c]
        expect(cache).to receive(:up_to_date?).with("module.pp", command, %w[module.c], env).and_return(false)
        expect(cache).to receive(:mkdir_p).with(".")
        expect(env).to receive(:execute).with("Preprocess module.pp", command).and_return(true)
        expect(File).to receive(:exists?).with("module.mf").and_return(true)
        expect(Environment).to receive(:parse_makefile_deps).with("module.mf", nil).and_return(%w[module.c one.h two.h])
        expect(FileUtils).to receive(:rm_f).with("module.mf")
        expect(cache).to receive(:register_build).with("module.pp", command, %w[module.c one.h two.h], env)

        expect(subject.run("module.pp", ["module.c"], cache, env, "CPP_CMD" => ["my_cpp", "${_SOURCES}"])).to eq("module.pp")
      end

      it "returns false if executing the preprocessor fails" do
        cache = double(Cache)
        command = %w[gcc -E -MMD -MF module.mf -o module.pp module.c]
        expect(cache).to receive(:up_to_date?).with("module.pp", command, %w[module.c], env).and_return(false)
        expect(cache).to receive(:mkdir_p).with(".")
        expect(env).to receive(:execute).with("Preprocess module.pp", command).and_return(false)

        expect(subject.run("module.pp", ["module.c"], cache, env, {})).to eq(false)
      end

    end
  end
end
