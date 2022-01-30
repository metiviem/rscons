class FileBuilder < Builder
  def self.name
    "File"
  end
  def run(options)
    FileUtils.mkdir_p(File.dirname(@target))
    File.binwrite(@target, ENV["file_contents"])
    true
  end
end
default do
  Environment.new do |env|
    env.add_builder(FileBuilder)
    env.File("^/file.txt")
    program = env.Program("^/simple.exe", Dir["*.c"])
    env.depends("^/simple.exe", "^/file.txt")
  end
end
