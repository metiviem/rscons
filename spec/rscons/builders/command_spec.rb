module Rscons
  module Builders
    describe Command do

      let(:command) { ['pandoc', '-fmarkdown', '-thtml', '-o${_TARGET}', '${_SOURCES}'] }
      let(:env) {Environment.new}
      subject {Command.new}

      it "invokes the command to build the target" do
        expected_cmd = ['pandoc', '-fmarkdown', '-thtml', '-ofoo.html', 'foo.md']
        expect(subject).to receive(:standard_build).with("PANDOC foo.html", "foo.html", expected_cmd, ["foo.md"], env, :cache)
        subject.run("foo.html", ["foo.md"], :cache, env,
                    "CMD" => command, "CMD_DESC" => "PANDOC")
      end

    end
  end
end
