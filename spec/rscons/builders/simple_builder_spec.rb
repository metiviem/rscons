module Rscons
  module Builders
    describe SimpleBuilder do
      let(:env) {Environment.new}

      it "should create a new builder with the given name (as a symbol) and action" do
        builder = Rscons::Builders::SimpleBuilder.new(:Foo) { 0x1234 }
        expect(builder.name).to eq("Foo")
        expect(builder.run(1,2,3,4,5)).to eq(0x1234)
      end

      it "should create a new builder with the given name (as a string) and action" do
        builder = Rscons::Builders::SimpleBuilder.new("Foo") { 0x1234 }
        expect(builder.name).to eq("Foo")
        expect(builder.run(1,2,3,4,5)).to eq(0x1234)
      end
    end
  end
end
