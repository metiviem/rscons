build do
  Rscons::Environment.new do |env|
    tempdir = ENV["TEMP"] || ENV["TMP"] || "/tmp"
    source_file = File.join(tempdir, "abs.c")
    File.open(source_file, "w") do |fh|
      fh.puts(<<-EOF)
      int main()
      {
        return 29;
      }
      EOF
    end
    env.Program("abs.exe", source_file)
  end
end
