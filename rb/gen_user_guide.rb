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
    attr_reader :number
    attr_reader :title
    attr_reader :page
    attr_reader :contents
    attr_reader :anchor
    def initialize(number, title, page, anchor)
      @number = number
      @title = title.gsub(/[`]/, "")
      @page = page
      @anchor = anchor
      @contents = ""
    end
    def append(contents)
      @contents += contents
    end
  end

  class Page
    attr_reader :name
    attr_reader :title
    attr_accessor :contents
    def initialize(name, title, contents = "")
      @name = name
      @title = title
      @contents = contents
    end
  end

  def initialize(input, output_file, multi_page)
    current_page =
      if multi_page
        nil
      else
        File.basename(output_file)
      end
    @sections = []
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
        anchor = make_anchor(section_number, title_text)
        if new_page or current_page.nil?
          current_page = anchor
        end
        @sections << Section.new(section_number, title_text, current_page, anchor)
        @sections.last.append("#{level_text} #{section_number} #{title_text}")
      elsif @sections.size > 0
        @sections.last.append(line)
      end
    end

    renderer = Redcarpet::Render::HTML.new
    @markdown_renderer = Redcarpet::Markdown.new(renderer)
    changelog = @markdown_renderer.render(File.read("CHANGELOG.md"))

    pages = [Page.new("toc", "Table of Contents", render_toc)]
    @sections.each do |section|
      unless pages.last.name == section.page
        pages << Page.new(section.page, section.title)
      end
      pages.last.contents += render_section(section)
    end

    pages.each do |page|
      page.contents.gsub!("${changelog}", changelog)
      page.contents.gsub!(%r{\$\{#(.+?)\}}) do |match|
        section_name = $1
        href = get_link_to_section(section_name)
        %[<a href="#{href}">#{section_name}</a>]
      end
    end

    template = File.read("rb/assets/user_guide.html.erb")
    erb = ERB.new(template, nil, "<>")

    if multi_page
      pages.each do |page|
        subpage_title = " - #{page.title}"
        content = page.contents
        html_result = erb.result(binding.clone)
        File.open(File.join(output_file, "#{page.name}.html"), "w") do |fh|
          fh.write(html_result)
        end
      end
    else
      subpage_title = ""
      content = pages.reduce("") do |result, page|
        result + page.contents
      end
      html_result = erb.result(binding.clone)
      File.open(output_file, "w") do |fh|
        fh.write(html_result)
      end
    end
  end

  def render_toc
    toc_content = %[<h1>Table of Contents</h1>\n]
    @sections.each do |section|
      indent = section.number.split(".").size - 1
      toc_content += %[<span style="padding-left: #{4 * indent}ex;">]
      toc_content += %[<a href="#{section.page}##{section.anchor}">#{section.number} #{section.title}</a><br/>\n]
      toc_content += %[</span>]
    end
    toc_content
  end

  def render_section(section)
    %[<a name="#{section.anchor}" />] + \
      @markdown_renderer.render(section.contents)
  end

  def make_anchor(section_number, section_title)
    "s" + ("#{section_number} #{section_title}").gsub(/[^a-zA-Z0-9]/, "_")
  end

  def get_link_to_section(section_name)
    section = @sections.find do |section|
      section.title == section_name
    end
    raise "Could not find section #{section_name}" unless section
    "#{section.page}##{section.anchor}"
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
Generator.new(input, "gen/user_guide", true)
