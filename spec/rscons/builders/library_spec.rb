module Rscons
  module Builders
    describe Library do
      let(:env) {Environment.new}
      subject {Library.new}

      it "supports overriding AR construction variable" do
        expect(subject).to receive(:standard_build).with("AR prog.a", "prog.a", ["sp-ar", "rcs", "prog.a", "prog.o"], ["prog.o"], env, :cache)
        subject.run(
          target: "prog.a",
          sources: ["prog.o"],
          cache: :cache,
          env: env,
          vars: {"AR" => "sp-ar"})
      end

      it "supports overriding ARCMD construction variable" do
        expect(subject).to receive(:standard_build).with("AR prog.a", "prog.a", ["special", "AR!", "prog.o"], ["prog.o"], env, :cache)
        subject.run(
          target: "prog.a",
          sources: ["prog.o"],
          cache: :cache,
          env: env,
          vars: {"ARCMD" => ["special", "AR!", "${_SOURCES}"]})
      end
    end
  end
end
