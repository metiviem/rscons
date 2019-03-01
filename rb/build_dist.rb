#!/usr/bin/env ruby

require "fileutils"

PROG_NAME = "rscons"
START_FILE = "bin/#{PROG_NAME}"
LIB_DIR = "lib"
DIST = "dist"

files_processed = {}

process_file = lambda do |file, fh|
  File.read(file, mode: "rb").each_line do |line|
    if line =~ /^\s*require(?:_relative)?\s*"(.*)"$/
      require_name = $1
      if require_name =~ %r{^#{PROG_NAME}(?:/.*)?$}
        path = "#{LIB_DIR}/#{require_name}.rb"
        if File.exists?(path)
          unless files_processed[path]
            files_processed[path] = true
            process_file[path, fh]
          end
        else
          raise "require path #{path.inspect} not found"
        end
      else
        fh.write(line)
      end
    else
      fh.write(line)
    end
  end
end

FileUtils.mkdir_p(DIST)

File.open("#{DIST}/#{PROG_NAME}", "wb", 0755) do |fh|
  process_file[START_FILE, fh]
end
