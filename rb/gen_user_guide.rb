#!/usr/bin/env ruby

require "erb"
require "fileutils"
require "redcarpet"
require "syntax"
require "rscons/version"

renderer = Redcarpet::Render::HTML.new
markdown = Redcarpet::Markdown.new(renderer)

def load_file(file_name)
  contents = File.read(file_name)
  contents.gsub(/\$\{include (.*?)\}/) do |match|
    include_file_name = $1
    File.read(include_file_name)
  end
end

input = load_file("doc/user_guide.md")

version = Rscons::VERSION
body = markdown.render(input)
template = File.read("rb/assets/user_guide.html.erb")

erb = ERB.new(template, nil, "<>")
html_result = erb.result

FileUtils.rm_rf("gen/user_guide")
FileUtils.mkdir_p("gen/user_guide")
File.open("gen/user_guide/user_guide.html", "w") do |fh|
  fh.write(html_result)
end
