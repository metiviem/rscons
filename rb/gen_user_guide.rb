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
    attr_reader :new_page
    attr_reader :contents
    def initialize(name, new_page)
      @name = name
      @new_page = new_page
      @contents = ""
    end
    def append(contents)
      @contents += contents
    end
  end

  def initialize(input, output_file, multi_file)
    @sections = [Section.new("index", false)]
    @current_section_number = [0]
    @lines = input.lines
    while @lines.size > 0
      line = @lines.slice!(0)
      if line =~ /^```(.*)$/
        @sections.last.append(gather_code_section($1))
      elsif line =~ /^(#+)(>)?\s*(.*)$/
        level_text, new_page_text, title_text = $1, $2, $3
        level = $1.size
        new_page = !new_page_text.nil?
        section_number = get_next_section_number(level)
        section_title = "#{section_number} #{title_text}"
        @sections << Section.new(section_title, new_page)
        @sections.last.append("#{level_text} #{section_title}")
      else
        @sections.last.append(line)
      end
    end

    renderer = Redcarpet::Render::HTML.new
    markdown = Redcarpet::Markdown.new(renderer)
    content = @sections.map do |section|
      markdown.render(section.contents)
    end.join("\n")

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
      %[<div class="code #{syntax}_code">\n#{convertor.convert(code)}\n</div>\n]
    else
      %[<div class="code">\n<pre>#{code}</pre>\n</div>\n]
    end
  end

  def get_next_section_number(level)
    if @current_section_number.size == level - 1
      @current_section_number << 1
    elsif @current_section_number.size >= level
      @current_section_number[level - 1] += 1
      @current_section_number.slice!(level, @current_section_number.size)
    else
      raise "Section level change from #{@current_section_number.size} to #{level}"
    end
    @current_section_number.join(".")
  end
end

input = load_file("doc/user_guide.md")
FileUtils.rm_rf("gen/user_guide")
FileUtils.mkdir_p("gen/user_guide")
Generator.new(input, "gen/user_guide/user_guide.html", false)
