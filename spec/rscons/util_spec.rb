module Rscons
  describe Util do

    describe ".make_relative_path" do
      context "when passed a relative path" do
        it "returns the path itself" do
          expect(Util.make_relative_path("foo/bar")).to eq "foo/bar"
        end
      end

      context "when passed an absolute path" do
        before(:each) do
          expect(Rscons).to receive(:absolute_path?).and_return(true)
        end

        context "on Windows" do
          it "returns a relative path corresponding to an absolute one" do
            expect(Util.make_relative_path("D:/foo/bar")).to eq "_D/foo/bar"
          end
        end

        context "on POSIX" do
          it "returns a relative path corresponding to an absolute one" do
            expect(Util.make_relative_path("/foo/bar")).to eq "_/foo/bar"
          end
        end
      end
    end

  end
end
