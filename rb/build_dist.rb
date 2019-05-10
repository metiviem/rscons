#!/usr/bin/env ruby

require "fileutils"
require "digest/md5"

if File.read("lib/rscons/version.rb") =~ /VERSION = "(.+)"/
  VERSION = $1
else
  raise "Could not determine version."
end
PROG_NAME = "rscons"
START_FILE = "bin/#{PROG_NAME}"
LIB_DIR = "lib"
DIST = "dist"

files_processed = {}
combined_file = []

combine_files = lambda do |file|
  File.read(file, mode: "rb").each_line do |line|
    if line =~ /^\s*require(?:_relative)?\s*"(.*)"$/
      require_name = $1
      if require_name =~ %r{^#{PROG_NAME}(?:/.*)?$}
        path = "#{LIB_DIR}/#{require_name}.rb"
        if File.exists?(path)
          unless files_processed[path]
            files_processed[path] = true
            combine_files[path]
          end
        else
          raise "require path #{path.inspect} not found"
        end
      else
        combined_file << line
      end
    else
      combined_file << line
    end
  end
end

combine_files[START_FILE]

# Strip Ruby comment lines and empty lines to save some space, but do not
# remove lines that are in heredoc sections. This isn't terribly robust to be
# used in the wild, but works for the heredoc instances for this project.
stripped_comments = []
heredoc_end = nil
combined_file.each do |line|
  if line =~ /<<-?([A-Z]+)/
    heredoc_end = $1
  end
  if heredoc_end and line =~ /^\s*#{heredoc_end}/
    heredoc_end = nil
  end
  if heredoc_end or not (line =~ /^\s*(#[^!].*)?$/)
    stripped_comments << line
  end
end

require "zlib"
compressed_script = Zlib::Deflate.deflate(stripped_comments.join)
escaped_compressed_script = compressed_script.gsub("#", "#1").gsub("\n", "#2").gsub("\r", "#3").gsub("\0", "#4")
hash = Digest::MD5.hexdigest(escaped_compressed_script)

FileUtils.mkdir_p(DIST)
File.open("#{DIST}/#{PROG_NAME}", "wb", 0755) do |fh|
  fh.write(<<EOF)
#!/usr/bin/env ruby
script = File.join(File.dirname(__FILE__), ".rscons-#{VERSION}-#{hash}.rb")
unless File.exists?(script)
  if File.read(__FILE__, mode: "rb") =~ /^#==>(.*)/
    escaped_compressed = $1
    unescaped_compressed = escaped_compressed.gsub("#4", "\\0").gsub("#3", "\\r").gsub("#2", "\\n").gsub("#1", "#")
    require "zlib"
    inflated = Zlib::Inflate.inflate(unescaped_compressed)
    File.open(script, "wb") do |fh|
      fh.write(inflated)
    end
  else
    raise "Could not decompress."
  end
end
load script
if __FILE__ == $0
  Rscons::Cli.run(ARGV)
end
#==>#{escaped_compressed_script}
EOF
end
