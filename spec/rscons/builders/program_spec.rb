module Rscons
  module Builders
    describe Program do
      let(:env) {Environment.new}
      subject {Program.new}

      it "supports overriding CC construction variable" do
        expect(subject).to receive(:standard_build).with("LD prog", "prog", ["sp-c++", "-o", "prog", "prog.o"], ["prog.o"], env, :cache)
        subject.run(
          target: "prog",
          sources: ["prog.o"],
          cache: :cache,
          env: env,
          vars: {"CC" => "sp-c++"})
      end

      it "supports overriding LDCMD construction variable" do
        expect(subject).to receive(:standard_build).with("LD prog.exe", "prog.exe", ["special", "LD!", "prog.o"], ["prog.o"], env, :cache)
        subject.run(
          target: "prog.exe",
          sources: ["prog.o"],
          cache: :cache,
          env: env,
          vars: {"LDCMD" => ["special", "LD!", "${_SOURCES}"]})
      end
    end
  end
end
