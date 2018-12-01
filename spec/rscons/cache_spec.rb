module Rscons
  describe Cache do
    before do
      allow(File).to receive(:read) { nil }
    end

    def build_from(cache)
      allow(JSON).to receive(:load) do
        cache
      end
      Cache.instance.tap do |cache|
        cache.send(:initialize!)
      end
    end

    describe "#targets" do
      it "returns a list of targets that are cached" do
        cache = {"targets" => {"t1" => {}, "t2" => {}, "t3" => {}}}
        expect(build_from(cache).targets).to eq ["t1", "t2", "t3"]
      end
    end

    describe "#mkdir_p" do
      it "makes directories and records any created in the cache" do
        _cache = {}
        cache = build_from(_cache)
        expect(File).to receive(:exists?).with("one").and_return(true)
        expect(File).to receive(:exists?).with("one/two").and_return(false)
        expect(FileUtils).to receive(:mkdir).with("one/two")
        expect(File).to receive(:exists?).with("one/two/three").and_return(false)
        expect(FileUtils).to receive(:mkdir).with("one/two/three")
        expect(File).to receive(:exists?).with("one").and_return(true)
        expect(File).to receive(:exists?).with("one/two").and_return(true)
        expect(File).to receive(:exists?).with("one/two/four").and_return(false)
        expect(FileUtils).to receive(:mkdir).with("one/two/four")
        cache.mkdir_p("one/two/three")
        cache.mkdir_p("one\\two\\four")
        expect(cache.directories).to eq ["one/two", "one/two/three", "one/two/four"]
      end

      it "handles absolute paths" do
        _cache = {}
        cache = build_from(_cache)
        expect(File).to receive(:exists?).with("/one").and_return(true)
        expect(File).to receive(:exists?).with("/one/two").and_return(false)
        expect(FileUtils).to receive(:mkdir).with("/one/two")
        cache.mkdir_p("/one/two")
        expect(cache.directories).to eq ["/one/two"]
      end
    end

    describe "#directories" do
      it "returns a list of directories that are cached" do
        _cache = {"directories" => {"dir1" => true, "dir2" => true}}
        expect(build_from(_cache).directories).to eq ["dir1", "dir2"]
      end
    end

    describe "#lookup_checksum" do
      it "does not re-calculate the checksum when it is already cached" do
        cache = build_from({})
        cache.instance_variable_set(:@lookup_checksums, {"f1" => "f1.chk"})
        expect(cache).to_not receive(:calculate_checksum)
        expect(cache.send(:lookup_checksum, "f1")).to eq "f1.chk"
      end

      it "calls calculate_checksum when the checksum is not cached" do
        cache = build_from({})
        expect(cache).to receive(:calculate_checksum).with("f1").and_return("ck")
        expect(cache.send(:lookup_checksum, "f1")).to eq "ck"
      end
    end

    describe "#calculate_checksum" do
      it "calculates the MD5 of the file contents" do
        contents = "contents"
        expect(File).to receive(:read).with("fname", mode: "rb").and_return(contents)
        expect(Digest::MD5).to receive(:hexdigest).with(contents).and_return("the_checksum")
        expect(build_from({}).send(:calculate_checksum, "fname")).to eq "the_checksum"
      end
    end

    describe "#validate_json_object" do
      it "raises an error when an unexpected object is passed" do
        cache = build_from({})
        expect {cache.__send__(:validate_json_object, :symbol)}.to raise_error /Unexpected cache value/
      end
    end
  end
end
