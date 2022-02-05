default do
  download "https://github.com/holtrop/rscons/releases/download/v2.3.0/rscons",
    "rscons-2.3.0",
    sha256sum: "27a6e0f65b446d0e862d357a3ecd2904ebdfb7a9d2c387f08fb687793ac8adf8"
  mtime = File.stat("rscons-2.3.0").mtime
  sleep 1
  download "https://github.com/holtrop/rscons/releases/download/v2.3.0/rscons",
    "rscons-2.3.0",
    sha256sum: "27a6e0f65b446d0e862d357a3ecd2904ebdfb7a9d2c387f08fb687793ac8adf8"
  unless mtime == File.stat("rscons-2.3.0").mtime
    raise "mtime changed"
  end
end

task "badchecksum" do
  download "https://github.com/holtrop/rscons/releases/download/v2.3.0/rscons",
    "rscons-2.3.0",
    sha256sum: "badbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbad0"
  puts "continued"
end

task "nochecksum" do
  File.binwrite("rscons-2.3.0", "hi")
  download "https://github.com/holtrop/rscons/releases/download/v2.3.0/rscons",
    "rscons-2.3.0"
end

task "redirectlimit" do
  download "http://github.com/holtrop/rscons/releases/download/v2.3.0/rscons",
    "rscons-2.3.0",
    sha256sum: "27a6e0f65b446d0e862d357a3ecd2904ebdfb7a9d2c387f08fb687793ac8adf8",
    redirect_limit: 0
end

task "badurl" do
  download "https://github.com/holtrop/rscons/releases/download/v2.3.0/rscons.nope",
    "rscons-2.3.0",
    sha256sum: "27a6e0f65b446d0e862d357a3ecd2904ebdfb7a9d2c387f08fb687793ac8adf8"
end

task "badhost" do
  download "http://ksfjliasjlaskdmflaskfmalisfjsd.com/foo",
    "foo",
    sha256sum: "27a6e0f65b446d0e862d357a3ecd2904ebdfb7a9d2c387f08fb687793ac8adf8"
end
