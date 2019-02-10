module Rscons
  module Builders
    describe SimpleBuilder do
      let(:env) {Environment.new}

      it "should create a new builder with the given action" do
        builder = Rscons::Builders::SimpleBuilder.new({}) { 0x1234 }
        expect(builder.run(1,2,3,4,5)).to eq(0x1234)
      end
    end
  end
end
