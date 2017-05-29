module Rscons
  describe Builder do
    describe "#run" do
      it "raises an error if called directly and not through a subclass" do
        expect{subject.run({})}.to raise_error /This method must be overridden in a subclass/
      end
    end
  end
end
