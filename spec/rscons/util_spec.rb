module Rscons
  describe Util do

    describe ".absolute_path?" do
      context "on Windows" do
        it "returns whether a path is absolute" do
          stub_const("RUBY_PLATFORM", "mingw")
          expect(Util.absolute_path?("/foo")).to be_truthy
          expect(Util.absolute_path?("\\Windows")).to be_truthy
          expect(Util.absolute_path?("C:\\Windows")).to be_truthy
          expect(Util.absolute_path?("f:\\stuff")).to be_truthy
          expect(Util.absolute_path?("g:/projects")).to be_truthy
          expect(Util.absolute_path?("x:foo")).to be_falsey
          expect(Util.absolute_path?("file.txt")).to be_falsey
        end
      end

      context "on non-Windows" do
        it "returns whether a path is absolute" do
          stub_const("RUBY_PLATFORM", "linux")
          expect(Util.absolute_path?("/foo")).to be_truthy
          expect(Util.absolute_path?("\\Windows")).to be_falsey
          expect(Util.absolute_path?("C:\\Windows")).to be_falsey
          expect(Util.absolute_path?("f:\\stuff")).to be_falsey
          expect(Util.absolute_path?("g:/projects")).to be_falsey
          expect(Util.absolute_path?("x:foo")).to be_falsey
          expect(Util.absolute_path?("file.txt")).to be_falsey
        end
      end
    end

    describe ".make_relative_path" do
      context "when passed a relative path" do
        it "returns the path itself" do
          expect(Util.make_relative_path("foo/bar")).to eq "foo/bar"
        end
      end

      context "when passed an absolute path" do
        before(:each) do
          expect(Util).to receive(:absolute_path?).and_return(true)
        end

        context "on Windows" do
          it "returns a relative path corresponding to an absolute one" do
            expect(Util.make_relative_path("D:/foo/bar")).to eq "_D/foo/bar"
          end
        end

        context "on non-Windows" do
          it "returns a relative path corresponding to an absolute one" do
            expect(Util.make_relative_path("/foo/bar")).to eq "_/foo/bar"
          end
        end
      end
    end

  end
end
