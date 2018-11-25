require 'fileutils'
require "open3"
require "set"

describe Rscons do

  def rm_rf(dir)
    FileUtils.rm_rf(dir)
    if File.exists?(dir)
      sleep 0.2
      FileUtils.rm_rf(dir)
      if File.exists?(dir)
        sleep 0.5
        FileUtils.rm_rf(dir)
        if File.exists?(dir)
          sleep 1.0
          FileUtils.rm_rf(dir)
          if File.exists?(dir)
            raise "Could not remove #{dir}"
          end
        end
      end
    end
  end

  before(:all) do
    @statics = {}
    @build_test_run_base_dir = File.expand_path("build_test_run")
    @run_results = Struct.new(:stdout, :stderr, :status)
    @owd = Dir.pwd
    rm_rf(@build_test_run_base_dir)
    FileUtils.mkdir_p(@build_test_run_base_dir)
  end

  before(:each) do
    @statics[:example_id] ||= 0
    @statics[:example_id] += 1
    @build_test_run_dir = "#{@build_test_run_base_dir}/test#{@statics[:example_id]}"
  end

  after(:each) do |example|
    Dir.chdir(@owd)
    if example.exception
      @statics[:keep_test_run_dir] = true
      puts "Leaving #{@build_test_run_dir} for inspection due to test failure"
    else
      rm_rf(@build_test_run_dir)
    end
  end

  after(:all) do
    unless @statics[:keep_test_run_dir]
      rm_rf(@build_test_run_base_dir)
    end
  end

  def test_dir(build_test_directory)
    Dir.chdir(@owd)
    rm_rf(@build_test_run_dir)
    FileUtils.cp_r("build_tests/#{build_test_directory}", @build_test_run_dir)
    FileUtils.mkdir("#{@build_test_run_dir}/_bin")
    Dir.chdir(@build_test_run_dir)
  end

  def create_exe(exe_name, contents)
    exe_file = "#{@build_test_run_dir}/_bin/#{exe_name}"
    File.open(exe_file, "wb") do |fh|
      fh.puts(contents)
    end
    FileUtils.chmod(0755, exe_file)
  end

  def file_sub(fname)
    contents = File.read(fname)
    replaced = ''
    contents.each_line do |line|
      replaced += yield(line)
    end
    File.open(fname, 'wb') do |fh|
      fh.write(replaced)
    end
  end

  def run_rscons(options = {})
    operation = options[:op] || "build"
    if operation.is_a?(Symbol)
      operation = operation.to_s
    end
    unless operation.is_a?(Array)
      operation = [operation]
    end
    rsconscript_args =
      if options[:rsconscript]
        %W[-f #{options[:rsconscript]}]
      else
        []
      end
    rscons_args = options[:rscons_args] || []
    command = %W[ruby -I. -r _simplecov_setup #{@owd}/test/rscons.rb] + rsconscript_args + rscons_args + operation
    @statics[:build_test_id] ||= 0
    @statics[:build_test_id] += 1
    command_prefix =
      if ENV["partial_specs"]
        "p"
      else
        "b"
      end
    command_name = "#{command_prefix}#{@statics[:build_test_id]}"
    File.open("_simplecov_setup.rb", "w") do |fh|
      fh.puts <<EOF
require "bundler"
Bundler.setup
require "simplecov"
class MyFormatter
  def format(*args)
  end
end
SimpleCov.start do
  root(#{@owd.inspect})
  command_name(#{command_name.inspect})
  filters.clear
  add_filter do |src|
    !(src.filename[SimpleCov.root])
  end
  formatter(MyFormatter)
end
# force color off
ENV["TERM"] = nil
#{options[:ruby_setup_code]}
EOF
    end
    stdout, stderr, status = nil, nil, nil
    Bundler.with_clean_env do
      env = ENV.to_h
      env["PATH"] = "#{@build_test_run_dir}/_bin#{File::PATH_SEPARATOR}#{env["PATH"]}"
      stdout, stderr, status = Open3.capture3(env, *command)
      File.open("#{@build_test_run_dir}/.stdout", "wb") do |fh|
        fh.write(stdout)
      end
      File.open("#{@build_test_run_dir}/.stderr", "wb") do |fh|
        fh.write(stderr)
      end
    end
    # Remove output lines generated as a result of the test environment
    stderr = stderr.lines.find_all do |line|
      not (line =~ /Warning: coverage data provided by Coverage.*exceeds number of lines/)
    end.join
    @run_results.new(stdout, stderr, status)
  end

  def lines(str)
    str.lines.map(&:chomp)
  end

  ###########################################################################
  # Tests
  ###########################################################################

  it 'builds a C program with one source file' do
    test_dir('simple')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(File.exists?('build/simple.o')).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C program\n"
  end

  it 'prints commands as they are executed' do
    test_dir('simple')
    result = run_rscons(rsconscript: "command.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      'gcc -c -o build/simple.o -MMD -MF build/simple.mf simple.c',
      "gcc -o simple.exe build/simple.o",
    ]
  end

  it 'prints short representations of the commands being executed' do
    test_dir('header')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      'CC build/header.o',
      "LD header.exe",
    ]
  end

  it 'builds a C program with one source file and one header file' do
    test_dir('header')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(File.exists?('build/header.o')).to be_truthy
    expect(`./header.exe`).to eq "The value is 2\n"
  end

  it 'rebuilds a C module when a header it depends on changes' do
    test_dir('header')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(`./header.exe`).to eq "The value is 2\n"
    file_sub('header.h') {|line| line.sub(/2/, '5')}
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(`./header.exe`).to eq "The value is 5\n"
  end

  it 'does not rebuild a C module when its dependencies have not changed' do
    test_dir('header')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      'CC build/header.o',
      "LD header.exe",
    ]
    expect(`./header.exe`).to eq "The value is 2\n"
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""
  end

  it "does not rebuild a C module when only the file's timestamp has changed" do
    test_dir('header')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      'CC build/header.o',
      "LD header.exe",
    ]
    expect(`./header.exe`).to eq "The value is 2\n"
    sleep 0.05
    file_sub('header.c') {|line| line}
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""
  end

  it 're-links a program when the link flags have changed' do
    test_dir('simple')
    result = run_rscons(rsconscript: "command.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      'gcc -c -o build/simple.o -MMD -MF build/simple.mf simple.c',
      "gcc -o simple.exe build/simple.o",
    ]
    result = run_rscons(rsconscript: "link_flag_change.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      "gcc -o simple.exe build/simple.o -Llibdir",
    ]
  end

  it 'builds object files in a different build directory' do
    test_dir('build_dir')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(`./build_dir.exe`).to eq "Hello from two()\n"
    expect(File.exists?('build_one/one.o')).to be_truthy
    expect(File.exists?('build_two/two.o')).to be_truthy
  end

  it "supports trailing slashes at the end of build_dir sources and destinations" do
    test_dir("build_dir")
    result = run_rscons(rsconscript: "slashes.rb")
    expect(result.stderr).to eq ""
    expect(`./build_dir.exe`).to eq "Hello from two()\n"
    expect(File.exists?("build_one/one.o")).to be_truthy
    expect(File.exists?("build_two/two.o")).to be_truthy
  end

  it 'uses build directories before build root' do
    test_dir('build_dir')
    result = run_rscons(rsconscript: "build_dirs_and_root.rb")
    expect(result.stderr).to eq ""
    expect(Set[*lines(result.stdout)]).to eq Set[
      "CC build/one/one.o",
      "CC build/two/two.o",
      "LD build_dir.exe",
    ]
  end

  it 'uses build_root if no build directories match' do
    test_dir('build_dir')
    result = run_rscons(rsconscript: "no_match_build_dir.rb")
    expect(result.stderr).to eq ""
    expect(Set[*lines(result.stdout)]).to eq Set[
      "CC build_root/src/one/one.o",
      "CC build_root/src/two/two.o",
      "LD build_dir.exe",
    ]
  end

  it "expands target and source paths starting with ^/ to be relative to the build root" do
    test_dir('build_dir')
    result = run_rscons(rsconscript: "carat.rb")
    expect(result.stderr).to eq ""
    expect(Set[*lines(result.stdout)]).to eq Set[
      %q{gcc -c -o build_root/one.o -MMD -MF build_root/one.mf -Isrc -Isrc/one -Isrc/two build_root/one.c},
      %q{gcc -c -o build_root/src/two/two.o -MMD -MF build_root/src/two/two.mf -Isrc -Isrc/one -Isrc/two src/two/two.c},
      %Q{gcc -o build_dir.exe build_root/src/two/two.o build_root/one.o},
    ]
  end

  it 'supports simple builders' do
    test_dir('json_to_yaml')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(File.exists?('foo.yml')).to be_truthy
    expect(IO.read('foo.yml')).to eq("---\nkey: value\n")
  end

  it 'cleans built files' do
    test_dir('build_dir')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(`./build_dir.exe`).to eq "Hello from two()\n"
    expect(File.exists?('build_one/one.o')).to be_truthy
    expect(File.exists?('build_two/two.o')).to be_truthy
    result = run_rscons(op: %w[clean])
    expect(File.exists?('build_one/one.o')).to be_falsey
    expect(File.exists?('build_two/two.o')).to be_falsey
    expect(File.exists?('build_one')).to be_falsey
    expect(File.exists?('build_two')).to be_falsey
    expect(File.exists?('build_dir.exe')).to be_falsey
    expect(File.exists?('src/one/one.c')).to be_truthy
  end

  it 'does not clean created directories if other non-rscons-generated files reside there' do
    test_dir('build_dir')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(`./build_dir.exe`).to eq "Hello from two()\n"
    expect(File.exists?('build_one/one.o')).to be_truthy
    expect(File.exists?('build_two/two.o')).to be_truthy
    File.open('build_two/tmp', 'w') { |fh| fh.puts "dum" }
    result = run_rscons(op: %w[clean])
    expect(File.exists?('build_one/one.o')).to be_falsey
    expect(File.exists?('build_two/two.o')).to be_falsey
    expect(File.exists?('build_one')).to be_falsey
    expect(File.exists?('build_two')).to be_truthy
    expect(File.exists?('build_dir.exe')).to be_falsey
    expect(File.exists?('src/one/one.c')).to be_truthy
  end

  it 'allows Ruby classes as custom builders to be used to construct files' do
    test_dir('custom_builder')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq ["CC build/program.o", "LD program.exe"]
    expect(File.exists?('inc.h')).to be_truthy
    expect(`./program.exe`).to eq "The value is 5678\n"
  end

  it 'supports custom builders with multiple targets' do
    test_dir('custom_builder')
    result = run_rscons(rsconscript: "multiple_targets.rb")
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    expect(slines[0]).to eq("CHGen inc.c")
    expect(Set[*slines[1..2]]).to eq(Set["CC build/program.o", "CC build/inc.o"])
    expect(slines[3]).to eq("LD program.exe")
    expect(File.exists?("inc.c")).to be_truthy
    expect(File.exists?("inc.h")).to be_truthy
    expect(`./program.exe`).to eq "The value is 42\n"

    File.open("inc.c", "w") {|fh| fh.puts "int THE_VALUE = 33;"}
    result = run_rscons(rsconscript: "multiple_targets.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq ["CHGen inc.c"]
    expect(`./program.exe`).to eq "The value is 42\n"
  end

  it 'allows cloning Environment objects' do
    test_dir('clone_env')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(Set[*lines(result.stdout)]).to eq Set[
      %q{gcc -c -o debug/program.o -MMD -MF debug/program.mf '-DSTRING="Debug Version"' -O2 src/program.c},
      %Q{gcc -o program-debug.exe debug/program.o},
      %q{gcc -c -o release/program.o -MMD -MF release/program.mf '-DSTRING="Release Version"' -O2 src/program.c},
      %Q{gcc -o program-release.exe release/program.o},
    ]
  end

  it 'clones all attributes of an Environment object by default' do
    test_dir('clone_env')
    result = run_rscons(rsconscript: "clone_all.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      %q{gcc -c -o build/program.o -MMD -MF build/program.mf -DSTRING="Hello" -O2 src/program.c},
      %q{post build/program.o},
      %Q{gcc -o program.exe build/program.o},
      %q{post program.exe},
      %q{post build/program.o},
      %Q{gcc -o program2.exe build/program.o},
      %q{post program2.exe},
    ]
  end

  it 'builds a C++ program with one source file' do
    test_dir('simple_cc')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(File.exists?('build/simple.o')).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C++ program\n"
  end

  it 'allows overriding construction variables for individual builder calls' do
    test_dir('two_sources')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(Set[*lines(result.stdout)]).to eq Set[
      'gcc -c -o one.o -MMD -MF one.mf -DONE one.c',
      'gcc -c -o build/two.o -MMD -MF build/two.mf two.c',
      "gcc -o two_sources.exe one.o build/two.o",
    ]
    expect(File.exists?("two_sources.exe")).to be_truthy
    expect(`./two_sources.exe`).to eq "This is a C program with two sources.\n"
  end

  it 'builds a static library archive' do
    test_dir('library')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(Set[*lines(result.stdout)]).to eq Set[
      'gcc -c -o build/one.o -MMD -MF build/one.mf -Dmake_lib one.c',
      'gcc -c -o build/two.o -MMD -MF build/two.mf -Dmake_lib two.c',
      'ar rcs lib.a build/one.o build/two.o',
      'gcc -c -o build/three.o -MMD -MF build/three.mf three.c',
      "gcc -o library.exe lib.a build/three.o",
    ]
    expect(File.exists?("library.exe")).to be_truthy
    expect(`ar t lib.a`).to eq "one.o\ntwo.o\n"
  end

  it 'supports build hooks to override construction variables' do
    test_dir("build_dir")
    result = run_rscons(rsconscript: "build_hooks.rb")
    expect(result.stderr).to eq ""
    expect(Set[*lines(result.stdout)]).to eq Set[
      'gcc -c -o build_one/one.o -MMD -MF build_one/one.mf -Isrc/one -Isrc/two -O1 src/one/one.c',
      'gcc -c -o build_two/two.o -MMD -MF build_two/two.mf -Isrc/one -Isrc/two -O2 src/two/two.c',
      'gcc -o build_hook.exe build_one/one.o build_two/two.o',
    ]
    expect(`./build_hook.exe`).to eq "Hello from two()\n"
  end

  it 'rebuilds when user-specified dependencies change' do
    test_dir('simple')

    File.open("program.ld", "w") {|fh| fh.puts("1")}
    result = run_rscons(rsconscript: "user_dependencies.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq ["CC build/simple.o", "LD simple.exe"]
    expect(File.exists?('build/simple.o')).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C program\n"

    File.open("program.ld", "w") {|fh| fh.puts("2")}
    result = run_rscons(rsconscript: "user_dependencies.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq(["LD simple.exe"])

    File.unlink("program.ld")
    result = run_rscons(rsconscript: "user_dependencies.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq ["LD simple.exe"]

    result = run_rscons(rsconscript: "user_dependencies.rb")
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""
  end

  unless ENV["omit_gdc_tests"]
    it "supports building D sources" do
      test_dir("d")
      result = run_rscons
      expect(result.stderr).to eq ""
      slines = lines(result.stdout)
      expect(slines).to include("gdc -c -o build/main.o -MMD -MF build/main.mf main.d")
      expect(slines).to include("gdc -c -o build/mod.o -MMD -MF build/mod.mf mod.d")
      expect(slines.last).to eq("gdc -o hello-d.exe build/main.o build/mod.o")
      expect(`./hello-d.exe`.rstrip).to eq "Hello from D, value is 42!"
    end

    it "does dependency generation for D sources" do
      test_dir("d")
      result = run_rscons
      expect(result.stderr).to eq ""
      slines = lines(result.stdout)
      expect(slines).to include("gdc -c -o build/main.o -MMD -MF build/main.mf main.d")
      expect(slines).to include("gdc -c -o build/mod.o -MMD -MF build/mod.mf mod.d")
      expect(slines.last).to eq("gdc -o hello-d.exe build/main.o build/mod.o")
      expect(`./hello-d.exe`.rstrip).to eq "Hello from D, value is 42!"
      fcontents = File.read("mod.d", mode: "rb").sub("42", "33")
      File.open("mod.d", "wb") {|fh| fh.write(fcontents)}
      result = run_rscons
      expect(result.stderr).to eq ""
      slines = lines(result.stdout)
      expect(slines).to include("gdc -c -o build/main.o -MMD -MF build/main.mf main.d")
      expect(slines).to include("gdc -c -o build/mod.o -MMD -MF build/mod.mf mod.d")
      expect(slines.last).to eq("gdc -o hello-d.exe build/main.o build/mod.o")
      expect(`./hello-d.exe`.rstrip).to eq "Hello from D, value is 33!"
    end

    it "creates shared libraries using D" do
      test_dir("shared_library")

      result = run_rscons(rsconscript: "shared_library_d.rb")
      # Currently gdc produces an error while trying to build the shared
      # library. Since this isn't really an rscons problem, I'm commenting out
      # this check. I'm not sure what I want to do about D support at this
      # point anyway...
      #expect(result.stderr).to eq ""
      slines = lines(result.stdout)
      if RUBY_PLATFORM =~ /mingw/
        expect(slines).to include("SHLD mine.dll")
      else
        expect(slines).to include("SHLD libmine.so")
      end
    end
  end

  it "supports disassembling object files" do
    test_dir("simple")

    result = run_rscons(rsconscript: "disassemble.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("simple.txt")).to be_truthy
    expect(File.read("simple.txt")).to match /Disassembly of section .text:/

    result = run_rscons(rsconscript: "disassemble.rb")
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""
  end

  it "supports preprocessing C sources" do
    test_dir("simple")
    result = run_rscons(rsconscript: "preprocess.rb")
    expect(result.stderr).to eq ""
    expect(File.read("simplepp.c")).to match /# \d+ "simple.c"/
    expect(`./simple.exe`).to eq "This is a simple C program\n"
  end

  it "supports preprocessing C++ sources" do
    test_dir("simple_cc")
    result = run_rscons(rsconscript: "preprocess.rb")
    expect(result.stderr).to eq ""
    expect(File.read("simplepp.cc")).to match /# \d+ "simple.cc"/
    expect(`./simple.exe`).to eq "This is a simple C++ program\n"
  end

  it "supports invoking builders with no sources and a build_root defined" do
    test_dir("simple")
    result = run_rscons(rsconscript: "build_root_builder_no_sources.rb")
    expect(result.stderr).to eq ""
  end

  it "expands construction variables in builder target and sources before invoking the builder" do
    test_dir('custom_builder')
    result = run_rscons(rsconscript: "cvar_expansion.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq ["CC build/program.o", "LD program.exe"]
    expect(File.exists?('inc.h')).to be_truthy
    expect(`./program.exe`).to eq "The value is 678\n"
  end

  it "supports lambdas as construction variable values" do
    test_dir "custom_builder"
    result = run_rscons(rsconscript: "cvar_lambda.rb")
    expect(result.stderr).to eq ""
    expect(`./program.exe`).to eq "The value is 5678\n"
  end

  it "supports registering build targets from within a build hook" do
    test_dir("simple")
    result = run_rscons(rsconscript: "register_target_in_build_hook.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("build/simple.o")).to be_truthy
    expect(File.exists?("build/simple.o.txt")).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C program\n"
  end

  it "supports multiple values for CXXSUFFIX" do
    test_dir("simple_cc")
    File.open("other.cccc", "w") {|fh| fh.puts}
    result = run_rscons(rsconscript: "cxxsuffix.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("build/simple.o")).to be_truthy
    expect(File.exists?("build/other.o")).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C++ program\n"
  end

  it "supports multiple values for CSUFFIX" do
    test_dir("build_dir")
    FileUtils.mv("src/one/one.c", "src/one/one.yargh")
    result = run_rscons(rsconscript: "csuffix.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("build/src/one/one.o")).to be_truthy
    expect(File.exists?("build/src/two/two.o")).to be_truthy
    expect(`./build_dir.exe`).to eq "Hello from two()\n"
  end

  it "supports multiple values for OBJSUFFIX" do
    test_dir("two_sources")
    result = run_rscons(rsconscript: "objsuffix.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("two_sources.exe")).to be_truthy
    expect(File.exists?("one.oooo")).to be_truthy
    expect(File.exists?("two.ooo")).to be_truthy
    expect(`./two_sources.exe`).to eq "This is a C program with two sources.\n"
  end

  it "supports multiple values for LIBSUFFIX" do
    test_dir("two_sources")
    result = run_rscons(rsconscript: "libsuffix.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("two_sources.exe")).to be_truthy
    expect(`./two_sources.exe`).to eq "This is a C program with two sources.\n"
  end

  it "supports multiple values for ASSUFFIX" do
    test_dir("two_sources")
    result = run_rscons(rsconscript: "assuffix.rb")
    expect(result.stderr).to eq ""
    expect(Set[*lines(result.stdout)]).to eq Set[
      "CC one.ssss",
      "CC two.sss",
      "AS build/one.o",
      "AS build/two.o",
      "LD two_sources.exe",
    ]
    expect(File.exists?("two_sources.exe")).to be_truthy
    expect(`./two_sources.exe`).to eq "This is a C program with two sources.\n"
  end

  it "supports dumping an Environment's construction variables" do
    test_dir("simple")
    result = run_rscons(rsconscript: "dump.rb")
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    expect(slines.include?(%{:foo => :bar})).to be_truthy
    expect(slines.include?(%{CFLAGS => ["-O2", "-fomit-frame-pointer"]})).to be_truthy
    expect(slines.include?(%{CPPPATH => []})).to be_truthy
  end

  it "considers deep dependencies when deciding whether to rerun Preprocess builder" do
    test_dir("preprocess")

    result = run_rscons
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq("Preprocess pp\n")
    expect(File.read("pp")).to match(%r{xyz42abc}m)

    result = run_rscons
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""

    File.open("bar.h", "w") do |fh|
      fh.puts "#define BAR abc88xyz"
    end
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq("Preprocess pp\n")
    expect(File.read("pp")).to match(%r{abc88xyz}m)
  end

  it "allows construction variable references which expand to arrays in sources of a build target" do
    test_dir("simple")
    result = run_rscons(rsconscript: "cvar_array.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("build/simple.o")).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C program\n"
  end

  it "supports registering multiple build targets with the same target path" do
    test_dir("build_dir")
    result = run_rscons(rsconscript: "multiple_targets_same_name.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("one.o")).to be_truthy
    expect(lines(result.stdout)).to eq([
      "CC one.o",
      "CC one.o",
    ])
  end

  it "expands target and source paths when builders are registered in build hooks" do
    test_dir("build_dir")
    result = run_rscons(rsconscript: "post_build_hook_expansion.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("one.o")).to be_truthy
    expect(File.exists?("two.o")).to be_truthy
    expect(lines(result.stdout)).to eq([
      "CC one.o",
      "CC two.o",
    ])
  end

  it "does not re-run previously successful builders if one fails" do
    test_dir('simple')
    File.open("two.c", "w") do |fh|
      fh.puts("FOO")
    end
    result = run_rscons(rsconscript: "cache_successful_builds_when_one_fails.rb",
                      rscons_args: %w[-j1])
    expect(result.stderr).to match /FOO/
    expect(File.exists?("simple.o")).to be_truthy
    expect(File.exists?("two.o")).to be_falsey

    File.open("two.c", "w") {|fh|}
    result = run_rscons(rsconscript: "cache_successful_builds_when_one_fails.rb",
                      rscons_args: %w[-j1])
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      "CC two.o",
    ]
  end

  it "allows overriding PROGSUFFIX" do
    test_dir("simple")
    result = run_rscons(rsconscript: "progsuffix.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      "CC build/simple.o",
      "LD simple.out",
    ]
  end

  it "does not use PROGSUFFIX when the Program target name expands to a value already containing an extension" do
    test_dir("simple")
    result = run_rscons(rsconscript: "progsuffix2.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      "CC build/simple.o",
      "LD simple.out",
    ]
  end

  it "allows overriding PROGSUFFIX from extra vars passed in to the builder" do
    test_dir("simple")
    result = run_rscons(rsconscript: "progsuffix3.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq [
      "CC build/simple.o",
      "LD simple.xyz",
    ]
  end

  it "creates object files under the build root for absolute source paths" do
    test_dir("simple")
    result = run_rscons(rsconscript: "absolute_source_path.rb")
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    expect(slines[0]).to match(%r{^CC build/.*/abs\.o$})
    expect(slines[1]).to eq "LD abs.exe"
  end

  it "creates shared libraries" do
    test_dir("shared_library")

    result = run_rscons
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    if RUBY_PLATFORM =~ /mingw/
      expect(slines).to include("SHLD mine.dll")
      expect(File.exists?("mine.dll")).to be_truthy
    else
      expect(slines).to include("SHLD libmine.so")
      expect(File.exists?("libmine.so")).to be_truthy
    end

    result = run_rscons
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""

    ld_library_path_prefix = (RUBY_PLATFORM =~ /mingw/ ? "" : "LD_LIBRARY_PATH=. ")
    expect(`#{ld_library_path_prefix}./test-shared.exe`).to match /Hi from one/
    expect(`./test-static.exe`).to match /Hi from one/
  end

  it "creates shared libraries using C++" do
    test_dir("shared_library")

    result = run_rscons(rsconscript: "shared_library_cxx.rb")
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    if RUBY_PLATFORM =~ /mingw/
      expect(slines).to include("SHLD mine.dll")
    else
      expect(slines).to include("SHLD libmine.so")
    end

    result = run_rscons(rsconscript: "shared_library_cxx.rb")
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""

    ld_library_path_prefix = (RUBY_PLATFORM =~ /mingw/ ? "" : "LD_LIBRARY_PATH=. ")
    expect(`#{ld_library_path_prefix}./test-shared.exe`).to match /Hi from one/
    expect(`./test-static.exe`).to match /Hi from one/
  end

  it "raises an error for a circular dependency" do
    test_dir("simple")
    result = run_rscons(rsconscript: "error_circular_dependency.rb")
    expect(result.stderr).to match /Possible circular dependency for (foo|bar|baz)/
    expect(result.status).to_not eq 0
  end

  it "raises an error for a circular dependency where a build target contains itself in its source list" do
    test_dir("simple")
    result = run_rscons(rsconscript: "error_circular_dependency2.rb")
    expect(result.stderr).to match /Possible circular dependency for foo/
    expect(result.status).to_not eq 0
  end

  it "orders builds to respect user dependencies" do
    test_dir("simple")
    result = run_rscons(rsconscript: "user_dep_build_order.rb", rscons_args: %w[-j4])
    expect(result.stderr).to eq ""
  end

  it "waits for all parallelized builds to complete if one fails" do
    test_dir("simple")
    result = run_rscons(rsconscript: "wait_for_builds_on_failure.rb", rscons_args: %w[-j4])
    expect(result.status).to_not eq 0
    expect(result.stderr).to match /Failed to build foo_1/
    expect(result.stderr).to match /Failed to build foo_2/
    expect(result.stderr).to match /Failed to build foo_3/
    expect(result.stderr).to match /Failed to build foo_4/
  end

  it "clones n_threads attribute when cloning an Environment" do
    test_dir("simple")
    result = run_rscons(rsconscript: "clone_n_threads.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq ["165"]
  end

  it "prints a builder's short description with 'command' echo mode if there is no command" do
    test_dir("build_dir")

    result = run_rscons(rsconscript: "echo_command_ruby_builder.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq ["Install inst.exe"]
  end

  it "supports a string for a builder's echoed 'command' with Environment#print_builder_run_message" do
    test_dir("build_dir")

    result = run_rscons(rsconscript: "echo_command_string.rb")
    expect(result.stderr).to eq ""
    expect(lines(result.stdout)).to eq ["MyBuilder foo command"]
  end

  context "colored output" do
    it "does not output in color with --color=off" do
      test_dir("simple")
      result = run_rscons(rscons_args: %w[--color=off])
      expect(result.stderr).to eq ""
      expect(result.stdout).to_not match(/\e\[/)
    end

    it "displays output in color with --color=force" do
      test_dir("simple")

      result = run_rscons(rscons_args: %w[--color=force])
      expect(result.stderr).to eq ""
      expect(result.stdout).to match(/\e\[/)

      File.open("simple.c", "wb") do |fh|
        fh.write("foobar")
      end
      result = run_rscons(rscons_args: %w[--color=force])
      expect(result.stderr).to match(/\e\[/)
    end
  end

  context "backward compatibility" do
    it "allows a builder to call Environment#run_builder in a non-threaded manner" do
      test_dir("simple")
      result = run_rscons(rsconscript: "run_builder.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "CC simple.o",
        "LD simple.exe",
      ]
    end

    it "allows a builder to call Environment#build_sources in a non-threaded manner" do
      test_dir("simple")
      result = run_rscons(rsconscript: "build_sources.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "CC simple.o",
        "CC build/two.o",
        "MyProgram simple.exe",
      ]
    end

    it "prints the failed build command for a non-threaded builder" do
      test_dir("simple")
      File.open("simple.c", "wb") do |fh|
        fh.write(<<EOF)
void one()
{
}
EOF
      end
      result = run_rscons(rsconscript: "build_sources.rb")
      expect(result.status).to_not eq 0
      expect(result.stderr).to match /main/
      expect(result.stdout).to match /Failed command was: gcc/
    end

    it "prints the failed build command for a threaded builder when called via Environment#run_builder without delayed execution" do
      test_dir("simple")
      File.open("simple.c", "wb") do |fh|
        fh.write("FOOBAR")
      end
      result = run_rscons(rsconscript: "run_builder.rb")
      expect(result.stderr).to match /Failed to build/
      expect(result.stdout).to match /Failed command was: gcc/
    end

    it "supports builders that call Builder#standard_build" do
      test_dir("simple")
      result = run_rscons(rsconscript: "standard_build.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq ["MyCommand simple.o"]
    end

    it "supports the old 3-parameter signature to Builder#produces?" do
      test_dir("simple")
      result = run_rscons(rsconscript: "bc_produces.rb")
      expect(result.stderr).to eq ""
    end

    it 'supports build hooks to override construction variables' do
      test_dir("build_dir")
      result = run_rscons(rsconscript: "backward_compatible_build_hooks.rb")
      expect(result.stderr).to eq ""
      expect(Set[*lines(result.stdout)]).to eq Set[
        'gcc -c -o one.o -MMD -MF one.mf -Isrc -Isrc/one -Isrc/two -O1 src/two/two.c',
        'gcc -c -o two.o -MMD -MF two.mf -Isrc -Isrc/one -Isrc/two -O2 src/two/two.c'
      ]
      expect(File.exists?('one.o')).to be_truthy
      expect(File.exists?('two.o')).to be_truthy
    end
  end

  context "CFile builder" do
    it "builds a .c file using flex and bison" do
      test_dir("cfile")

      result = run_rscons
      expect(result.stderr).to eq ""
      expect(Set[*lines(result.stdout)]).to eq Set[
        "LEX lexer.c",
        "YACC parser.c",
      ]

      result = run_rscons
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""
    end

    it "raises an error when an unknown source file is specified" do
      test_dir("cfile")
      result = run_rscons(rsconscript: "error_unknown_extension.rb")
      expect(result.stderr).to match /Unknown source file .foo.bar. for CFile builder/
      expect(result.status).to_not eq 0
    end
  end

  context "Command builder" do
    it "allows executing an arbitrary command" do
      test_dir('simple')

      result = run_rscons(rsconscript: "command_builder.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq ["BuildIt simple.exe"]
      expect(`./simple.exe`).to eq "This is a simple C program\n"

      result = run_rscons(rsconscript: "command_builder.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""
    end

    it "allows redirecting standard output to a file" do
      test_dir("simple")

      result = run_rscons(rsconscript: "command_redirect.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "CC simple.o",
        "My Disassemble simple.txt",
      ]
      expect(File.read("simple.txt")).to match /Disassembly of section .text:/
    end
  end

  context "Directory builder" do
    it "creates the requested directory" do
      test_dir("simple")
      result = run_rscons(rsconscript: "directory.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq(["Directory teh_dir"])
      expect(File.directory?("teh_dir")).to be_truthy
    end

    it "succeeds when the requested directory already exists" do
      test_dir("simple")
      FileUtils.mkdir("teh_dir")
      result = run_rscons(rsconscript: "directory.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""
      expect(File.directory?("teh_dir")).to be_truthy
    end

    it "fails when the target path is a file" do
      test_dir("simple")
      FileUtils.touch("teh_dir")
      result = run_rscons(rsconscript: "directory.rb")
      expect(result.stderr).to match %r{Error: `teh_dir' already exists and is not a directory}
    end
  end

  context "Install buildler" do
    it "copies a file to the target file name" do
      test_dir("build_dir")

      result = run_rscons(rsconscript: "install.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq ["Install inst.exe"]

      result = run_rscons(rsconscript: "install.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""

      expect(File.exists?("inst.exe")).to be_truthy
      expect(File.read("inst.exe", mode: "rb")).to eq(File.read("install.rb", mode: "rb"))

      FileUtils.rm("inst.exe")
      result = run_rscons(rsconscript: "install.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq ["Install inst.exe"]
    end

    it "operates the same as a Copy builder" do
      test_dir("build_dir")

      result = run_rscons(rsconscript: "copy.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq ["Copy inst.exe"]

      result = run_rscons(rsconscript: "copy.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""

      expect(File.exists?("inst.exe")).to be_truthy
      expect(File.read("inst.exe", mode: "rb")).to eq(File.read("copy.rb", mode: "rb"))

      FileUtils.rm("inst.exe")
      result = run_rscons(rsconscript: "copy.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq ["Copy inst.exe"]
    end

    it "copies a file to the target directory name" do
      test_dir "build_dir"

      result = run_rscons(rsconscript: "install_directory.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to include("Install inst")
      expect(File.exists?("inst/install_directory.rb")).to be_truthy
      expect(File.read("inst/install_directory.rb", mode: "rb")).to eq(File.read("install_directory.rb", mode: "rb"))

      result = run_rscons(rsconscript: "install_directory.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""
    end

    it "copies a directory to the non-existent target directory name" do
      test_dir "build_dir"
      result = run_rscons(rsconscript: "install_directory.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to include("Install noexist/src")
      %w[src/one/one.c src/two/two.c src/two/two.h].each do |f|
        expect(File.exists?("noexist/#{f}")).to be_truthy
        expect(File.read("noexist/#{f}", mode: "rb")).to eq(File.read(f, mode: "rb"))
      end
    end

    it "copies a directory to the existent target directory name" do
      test_dir "build_dir"
      result = run_rscons(rsconscript: "install_directory.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to include("Install exist/src")
      %w[src/one/one.c src/two/two.c src/two/two.h].each do |f|
        expect(File.exists?("exist/#{f}")).to be_truthy
        expect(File.read("exist/#{f}", mode: "rb")).to eq(File.read(f, mode: "rb"))
      end
    end
  end

  context "phony targets" do
    it "allows specifying a Symbol as a target name and reruns the builder if the sources or command have changed" do
      test_dir("simple")

      result = run_rscons(rsconscript: "phony_target.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq([
        "CC build/simple.o",
        "LD simple.exe",
        "Checker simple.exe",
      ])

      result = run_rscons(rsconscript: "phony_target.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""

      FileUtils.cp("phony_target.rb", "phony_target2.rb")
      file_sub("phony_target2.rb") {|line| line.sub(/.*Program.*/, "")}
      File.open("simple.exe", "w") do |fh|
        fh.puts "Changed simple.exe"
      end
      result = run_rscons(rsconscript: "phony_target2.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq([
        "Checker simple.exe",
      ])
    end
  end

  context "Environment#clear_targets" do
    it "clears registered targets" do
      test_dir("simple")
      result = run_rscons(rsconscript: "clear_targets.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""
    end
  end

  context "Cache management" do
    it "prints a warning when the cache is corrupt" do
      test_dir("simple")
      File.open(Rscons::Cache::CACHE_FILE, "w") do |fh|
        fh.puts("[1]")
      end
      result = run_rscons
      expect(result.stderr).to match /Warning.*was corrupt. Contents:/
    end

    it "removes the cache file on a clean operation" do
      test_dir("simple")
      result = run_rscons
      expect(result.stderr).to eq ""
      expect(File.exists?(Rscons::Cache::CACHE_FILE)).to be_truthy
      result = run_rscons(op: %w[clean])
      expect(result.stderr).to eq ""
      expect(File.exists?(Rscons::Cache::CACHE_FILE)).to be_falsey
    end

    it "forces a build when the target file does not exist and is not in the cache" do
      test_dir("simple")
      expect(File.exists?("simple.exe")).to be_falsey
      result = run_rscons
      expect(result.stderr).to eq ""
      expect(File.exists?("simple.exe")).to be_truthy
    end

    it "forces a build when the target file does exist but is not in the cache" do
      test_dir("simple")
      File.open("simple.exe", "wb") do |fh|
        fh.write("hi")
      end
      result = run_rscons
      expect(result.stderr).to eq ""
      expect(File.exists?("simple.exe")).to be_truthy
      expect(File.read("simple.exe", mode: "rb")).to_not eq "hi"
    end

    it "forces a build when the target file exists and is in the cache but has changed since cached" do
      test_dir("simple")
      result = run_rscons
      expect(result.stderr).to eq ""
      File.open("simple.exe", "wb") do |fh|
        fh.write("hi")
      end
      test_dir("simple")
      result = run_rscons
      expect(result.stderr).to eq ""
      expect(File.exists?("simple.exe")).to be_truthy
      expect(File.read("simple.exe", mode: "rb")).to_not eq "hi"
    end

    it "forces a build when the command changes" do
      test_dir("simple")

      result = run_rscons
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "CC build/simple.o",
        "LD simple.exe",
      ]

      result = run_rscons(rsconscript: "cache_command_change.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "LD simple.exe",
      ]
    end

    it "forces a build when there is a new dependency" do
      test_dir("simple")

      result = run_rscons(rsconscript: "cache_new_dep1.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "CC simple.o",
        "LD simple.exe",
      ]

      result = run_rscons(rsconscript: "cache_new_dep2.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "LD simple.exe",
      ]
    end

    it "forces a build when a dependency's checksum has changed" do
      test_dir("simple")

      result = run_rscons(rsconscript: "cache_dep_checksum_change.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq ["Copy simple.copy"]
      File.open("simple.c", "wb") do |fh|
        fh.write("hi")
      end

      result = run_rscons(rsconscript: "cache_dep_checksum_change.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq ["Copy simple.copy"]
    end

    it "forces a rebuild with strict_deps=true when dependency order changes" do
      test_dir("two_sources")

      File.open("sources", "wb") do |fh|
        fh.write("one.o two.o")
      end
      result = run_rscons(rsconscript: "cache_strict_deps.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to include "gcc -o program.exe one.o two.o"

      result = run_rscons(rsconscript: "cache_strict_deps.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""

      File.open("sources", "wb") do |fh|
        fh.write("two.o one.o")
      end
      result = run_rscons(rsconscript: "cache_strict_deps.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to include "gcc -o program.exe one.o two.o"
    end

    it "forces a rebuild when there is a new user dependency" do
      test_dir("simple")

      File.open("foo", "wb") {|fh| fh.write("hi")}
      File.open("user_deps", "wb") {|fh| fh.write("")}
      result = run_rscons(rsconscript: "cache_user_dep.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "CC build/simple.o",
        "LD simple.exe",
      ]

      File.open("user_deps", "wb") {|fh| fh.write("foo")}
      result = run_rscons(rsconscript: "cache_user_dep.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "LD simple.exe",
      ]
    end

    it "forces a rebuild when a user dependency file checksum has changed" do
      test_dir("simple")

      File.open("foo", "wb") {|fh| fh.write("hi")}
      File.open("user_deps", "wb") {|fh| fh.write("foo")}
      result = run_rscons(rsconscript: "cache_user_dep.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "CC build/simple.o",
        "LD simple.exe",
      ]

      result = run_rscons(rsconscript: "cache_user_dep.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""

      File.open("foo", "wb") {|fh| fh.write("hi2")}
      result = run_rscons(rsconscript: "cache_user_dep.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "LD simple.exe",
      ]
    end

    it "allows a VarSet to be passed in as the command parameter" do
      test_dir("simple")
      result = run_rscons(rsconscript: "cache_varset.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "TestBuilder foo",
      ]
      result = run_rscons(rsconscript: "cache_varset.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""
    end

    context "debugging" do
      it "prints a message when the target does not exist" do
        test_dir("simple")
        result = run_rscons(rsconscript: "cache_debugging.rb")
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Target foo\.o needs rebuilding because it does not exist on disk/
      end

      it "prints a message when there is no cached build information for the target" do
        test_dir("simple")
        FileUtils.touch("foo.o")
        result = run_rscons(rsconscript: "cache_debugging.rb")
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Target foo\.o needs rebuilding because there is no cached build information for it/
      end

      it "prints a message when the target file has changed on disk" do
        test_dir("simple")
        result = run_rscons(rsconscript: "cache_debugging.rb")
        expect(result.stderr).to eq ""
        File.open("foo.o", "wb") {|fh| fh.puts "hi"}
        result = run_rscons(rsconscript: "cache_debugging.rb")
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Target foo\.o needs rebuilding because it has been changed on disk since being built last/
      end

      it "prints a message when the command has changed" do
        test_dir("simple")
        result = run_rscons(rsconscript: "cache_debugging.rb")
        expect(result.stderr).to eq ""
        result = run_rscons(rsconscript: "cache_debugging.rb", op: %w[build command_change=yes])
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Target foo\.o needs rebuilding because the command used to build it has changed/
      end

      it "prints a message when strict_deps is in use and the set of dependencies does not match" do
        test_dir("simple")
        result = run_rscons(rsconscript: "cache_debugging.rb", op: %w[build strict_deps1=yes])
        expect(result.stderr).to eq ""
        result = run_rscons(rsconscript: "cache_debugging.rb", op: %w[build strict_deps2=yes])
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Target foo\.o needs rebuilding because the :strict_deps option is given and the set of dependencies does not match the previous set of dependencies/
      end

      it "prints a message when there is a new dependency" do
        test_dir("simple")
        result = run_rscons(rsconscript: "cache_debugging.rb")
        expect(result.stderr).to eq ""
        result = run_rscons(rsconscript: "cache_debugging.rb", op: %w[build new_dep=yes])
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Target foo\.o needs rebuilding because there are new dependencies/
      end

      it "prints a message when there is a new user-specified dependency" do
        test_dir("simple")
        result = run_rscons(rsconscript: "cache_debugging.rb")
        expect(result.stderr).to eq ""
        result = run_rscons(rsconscript: "cache_debugging.rb", op: %w[build new_user_dep=yes])
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Target foo\.o needs rebuilding because the set of user-specified dependency files has changed/
      end

      it "prints a message when a dependency file has changed" do
        test_dir("simple")
        result = run_rscons(rsconscript: "cache_debugging.rb")
        expect(result.stderr).to eq ""
        f = File.read("simple.c", mode: "rb")
        f += "\n"
        File.open("simple.c", "wb") do |fh|
          fh.write(f)
        end
        result = run_rscons(rsconscript: "cache_debugging.rb")
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Target foo\.o needs rebuilding because dependency file simple\.c has changed/
      end
    end
  end

  context "Object builder" do
    it "allows overriding CCCMD construction variable" do
      test_dir("simple")
      result = run_rscons(rsconscript: "override_cccmd.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "gcc -c -o simple.o -Dfoobar simple.c",
      ]
    end

    it "allows overriding DEPFILESUFFIX construction variable" do
      test_dir("simple")
      result = run_rscons(rsconscript: "override_depfilesuffix.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to eq [
        "gcc -c -o simple.o -MMD -MF simple.deppy simple.c",
      ]
    end

    it "raises an error when given a source file with an unknown suffix" do
      test_dir("simple")
      result = run_rscons(rsconscript: "error_unknown_suffix.rb")
      expect(result.stderr).to match /unknown input file type: "foo.xyz"/
    end
  end

  context "SharedObject builder" do
    it "raises an error when given a source file with an unknown suffix" do
      test_dir("shared_library")
      result = run_rscons(rsconscript: "error_unknown_suffix.rb")
      expect(result.stderr).to match /unknown input file type: "foo.xyz"/
    end
  end

  context "Library builder" do
    it "allows overriding ARCMD construction variable" do
      test_dir("library")
      result = run_rscons(rsconscript: "override_arcmd.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to include "ar rcf lib.a build/one.o build/three.o build/two.o"
    end
  end

  context "SharedLibrary builder" do
    it "allows explicitly specifying SHLD construction variable value" do
      test_dir("shared_library")

      result = run_rscons(rsconscript: "shared_library_set_shld.rb")
      expect(result.stderr).to eq ""
      slines = lines(result.stdout)
      if RUBY_PLATFORM =~ /mingw/
        expect(slines).to include("SHLD mine.dll")
      else
        expect(slines).to include("SHLD libmine.so")
      end
    end
  end

  context "multi-threading" do
    it "waits for subcommands in threads for builders that support threaded commands" do
      test_dir("simple")
      start_time = Time.new
      result = run_rscons(rsconscript: "threading.rb", rscons_args: %w[-j 4])
      expect(result.stderr).to eq ""
      expect(Set[*lines(result.stdout)]).to eq Set[
        "ThreadedTestBuilder a",
        "ThreadedTestBuilder b",
        "ThreadedTestBuilder c",
        "NonThreadedTestBuilder d",
      ]
      elapsed = Time.new - start_time
      expect(elapsed).to be < 4
    end

    it "allows the user to specify that a target be built after another" do
      test_dir("custom_builder")
      result = run_rscons(rsconscript: "build_after.rb", rscons_args: %w[-j 4])
      expect(result.stderr).to eq ""
    end

    it "allows the user to specify side-effect files produced by another builder" do
      test_dir("custom_builder")
      result = run_rscons(rsconscript: "produces.rb", rscons_args: %w[-j 4])
      expect(result.stderr).to eq ""
      expect(File.exists?("copy_inc.h")).to be_truthy
    end
  end

  context "CLI" do
    it "shows the version number and exits with --version argument" do
      test_dir("simple")
      result = run_rscons(rscons_args: %w[--version])
      expect(result.stderr).to eq ""
      expect(result.status).to eq 0
      expect(result.stdout).to match /version #{Rscons::VERSION}/
    end

    it "shows CLI help and exits with --help argument" do
      test_dir("simple")
      result = run_rscons(rscons_args: %w[--help])
      expect(result.stderr).to eq ""
      expect(result.status).to eq 0
      expect(result.stdout).to match /Usage:/
    end

    it "prints an error and exits with an error status when a default Rsconscript cannot be found" do
      test_dir("simple")
      FileUtils.rm_f("Rsconscript")
      result = run_rscons
      expect(result.stderr).to match /Could not find the Rsconscript to execute/
      expect(result.status).to_not eq 0
    end

    it "prints an error and exits with an error status when the given Rsconscript cannot be read" do
      test_dir("simple")
      result = run_rscons(rsconscript: "nonexistent")
      expect(result.stderr).to match /Cannot read nonexistent/
      expect(result.status).to_not eq 0
    end
  end

  context "configure" do
    it "raises a method not found error for configure methods called outside a configure block" do
      test_dir "configure"
      result = run_rscons(rsconscript: "scope.rb")
      expect(result.stderr).to match /NoMethodError/
      expect(result.status).to_not eq 0
    end

    context "check_c_compiler" do
      {"check_c_compiler.rb" => "when no arguments are given",
       "check_c_compiler_find_first.rb" => "when arguments are given"}.each_pair do |rsconscript, desc|
        context desc do
          it "finds the first listed C compiler" do
            test_dir "configure"
            result = run_rscons(rsconscript: rsconscript, op: "configure")
            expect(result.stderr).to eq ""
            expect(result.status).to eq 0
            expect(result.stdout).to match /Checking for C compiler\.\.\. gcc/
          end

          it "finds the second listed C compiler" do
            test_dir "configure"
            create_exe "gcc", "exit 1"
            result = run_rscons(rsconscript: rsconscript, op: "configure")
            expect(result.stderr).to eq ""
            expect(result.status).to eq 0
            expect(result.stdout).to match /Checking for C compiler\.\.\. clang/
          end

          it "fails to configure when it cannot find a C compiler" do
            test_dir "configure"
            create_exe "gcc", "exit 1"
            create_exe "clang", "exit 1"
            result = run_rscons(rsconscript: rsconscript, op: "configure")
            expect(result.stderr).to eq ""
            expect(result.status).to_not eq 0
            expect(result.stdout).to match /Checking for C compiler\.\.\. not found/
          end
        end
      end
    end

    context "check_cxx_compiler" do
      {"check_cxx_compiler.rb" => "when no arguments are given",
       "check_cxx_compiler_find_first.rb" => "when arguments are given"}.each_pair do |rsconscript, desc|
        context desc do
          it "finds the first listed C++ compiler" do
            test_dir "configure"
            result = run_rscons(rsconscript: rsconscript, op: "configure")
            expect(result.stderr).to eq ""
            expect(result.status).to eq 0
            expect(result.stdout).to match /Checking for C\+\+ compiler\.\.\. g\+\+/
          end

          it "finds the second listed C++ compiler" do
            test_dir "configure"
            create_exe "g++", "exit 1"
            result = run_rscons(rsconscript: rsconscript, op: "configure")
            expect(result.stderr).to eq ""
            expect(result.status).to eq 0
            expect(result.stdout).to match /Checking for C\+\+ compiler\.\.\. clang\+\+/
          end

          it "fails to configure when it cannot find a C++ compiler" do
            test_dir "configure"
            create_exe "g++", "exit 1"
            create_exe "clang++", "exit 1"
            result = run_rscons(rsconscript: rsconscript, op: "configure")
            expect(result.stderr).to eq ""
            expect(result.status).to_not eq 0
            expect(result.stdout).to match /Checking for C\+\+ compiler\.\.\. not found/
          end
        end
      end
    end

    context "check_d_compiler" do
      {"check_d_compiler.rb" => "when no arguments are given",
       "check_d_compiler_find_first.rb" => "when arguments are given"}.each_pair do |rsconscript, desc|
        context desc do
          it "finds the first listed D compiler" do
            test_dir "configure"
            result = run_rscons(rsconscript: rsconscript, op: "configure")
            expect(result.stderr).to eq ""
            expect(result.status).to eq 0
            expect(result.stdout).to match /Checking for D compiler\.\.\. gdc/
          end

          it "finds the second listed D compiler" do
            test_dir "configure"
            create_exe "gdc", "exit 1"
            result = run_rscons(rsconscript: rsconscript, op: "configure")
            expect(result.stderr).to eq ""
            expect(result.status).to eq 0
            expect(result.stdout).to match /Checking for D compiler\.\.\. ldc2/
          end

          it "fails to configure when it cannot find a D compiler" do
            test_dir "configure"
            create_exe "gdc", "exit 1"
            create_exe "ldc2", "exit 1"
            result = run_rscons(rsconscript: rsconscript, op: "configure")
            expect(result.stderr).to eq ""
            expect(result.status).to_not eq 0
            expect(result.stdout).to match /Checking for D compiler\.\.\. not found/
          end
        end
      end
    end

    context "check_c_header" do
      it "succeeds when the requested header is found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_c_header_success.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for C header 'string\.h'... found/
      end

      it "fails when the requested header is not found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_c_header_failure.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to_not eq 0
        expect(result.stdout).to match /Checking for C header 'not___found\.h'... not found/
      end

      it "succeeds when the requested header is not found but :fail is set to false" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_c_header_no_fail.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for C header 'not___found\.h'... not found/
      end
    end

    context "check_cxx_header" do
      it "succeeds when the requested header is found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_cxx_header_success.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for C\+\+ header 'string\.h'... found/
      end

      it "fails when the requested header is not found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_cxx_header_failure.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to_not eq 0
        expect(result.stdout).to match /Checking for C\+\+ header 'not___found\.h'... not found/
      end

      it "succeeds when the requested header is not found but :fail is set to false" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_cxx_header_no_fail.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for C\+\+ header 'not___found\.h'... not found/
      end
    end

    context "check_d_import" do
      it "succeeds when the requested import is found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_d_import_success.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for D import 'std\.stdio'... found/
      end

      it "fails when the requested import is not found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_d_import_failure.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to_not eq 0
        expect(result.stdout).to match /Checking for D import 'not\.found'... not found/
      end

      it "succeeds when the requested import is not found but :fail is set to false" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_d_import_no_fail.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for D import 'not\.found'... not found/
      end
    end

    context "check_lib" do
      it "succeeds when the requested library is found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_lib_success.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for library 'm'... found/
      end

      it "fails when the requested library is not found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_lib_failure.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to_not eq 0
        expect(result.stdout).to match /Checking for library 'mfoofoo'... not found/
      end

      it "succeeds when the requested library is not found but :fail is set to false" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_lib_no_fail.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for library 'mfoofoo'... not found/
      end
    end

    context "check_program" do
      it "succeeds when the requested program is found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_program_success.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for program 'find'... .*find/
      end

      it "fails when the requested program is not found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_program_failure.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to_not eq 0
        expect(result.stdout).to match /Checking for program 'program-that-is-not-found'... not found/
      end

      it "succeeds when the requested program is not found but :fail is set to false" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_program_no_fail.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for program 'program-that-is-not-found'... not found/
      end
    end

    context "check_cfg" do
      it "stores flags and uses them during a build operation" do
        test_dir "configure"
        create_exe "my-config", "echo '-DMYCONFIG -lm'"
        result = run_rscons(rsconscript: "check_cfg.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking 'my-config'\.\.\. found/
        result = run_rscons(rsconscript: "check_cfg.rb", op: "build")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /gcc.*-o.*\.o.*-DMYCONFIG/
        expect(result.stdout).to match /gcc.*-o myconfigtest.*-lm/
      end
    end
  end

end
