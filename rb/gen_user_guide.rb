#!/usr/bin/env ruby

require "erb"
require "fileutils"
require "redcarpet"
require "syntax"
require "syntax/convertors/html"
require "rscons/version"

def load_file(file_name)
  contents = File.read(file_name)
  contents.gsub(/\$\{include (.*?)\}/) do |match|
    include_file_name = $1
    File.read(include_file_name)
  end
end

class Generator
  class Section
    attr_reader :name
    attr_reader :contents
    def initialize(name)
      @name = name
      @contents = ""
    end
    def append(contents)
      @contents += contents
    end
  end

  def initialize(input, output_file, multi_file)
    @sections = [Section.new("index")]
    @lines = input.lines
    while @lines.size > 0
      line = @lines.slice!(0)
      if line =~ /^```(.*)$/
        @sections.last.append(gather_code_section($1))
      else
        @sections.last.append(line)
      end
    end

    renderer = Redcarpet::Render::HTML.new
    markdown = Redcarpet::Markdown.new(renderer)
    body = markdown.render(@sections.last.contents)

    template = File.read("rb/assets/user_guide.html.erb")
    erb = ERB.new(template, nil, "<>")
    html_result = erb.result(binding.clone)
    File.open(output_file, "w") do |fh|
      fh.write(html_result)
    end
  end

  def gather_code_section(syntax)
    code = ""
    loop do
      line = @lines.slice!(0)
      if line =~ /^```/
        break
      end
      code += line
    end
    if syntax != ""
      convertor = Syntax::Convertors::HTML.for_syntax(syntax)
      convertor.convert(code)
    else
      "<pre>#{code}</pre>"
    end
  end
end

input = load_file("doc/user_guide.md")
FileUtils.rm_rf("gen/user_guide")
FileUtils.mkdir_p("gen/user_guide")
Generator.new(input, "gen/user_guide/user_guide.html", false)
