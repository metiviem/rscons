require 'fileutils'
require "open3"
require "set"
require "tmpdir"

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
    if RUBY_PLATFORM =~ /mingw/
      exe_file += ".bat"
    end
    File.open(exe_file, "wb") do |fh|
      fh.puts("#!/bin/sh")
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
    if ENV["dist_specs"]
      exe = "#{@owd}/test/rscons.rb"
    else
      exe = "#{@owd}/bin/rscons"
    end
    command = %W[ruby -I. -r _simplecov_setup #{exe}] + rsconscript_args + rscons_args + operation
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
      unless ENV["dist_specs"]
        fh.puts %[$LOAD_PATH.unshift(#{@owd.inspect} + "/lib")]
      end
    end
    stdout, stderr, status = nil, nil, nil
    Bundler.with_clean_env do
      env = ENV.to_h
      path = ["#{@build_test_run_dir}/_bin", "#{env["PATH"]}"]
      if options[:path]
        path = Array(options[:path]) + path
      end
      env["PATH"] = path.join(File::PATH_SEPARATOR)
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

  def verify_lines(lines, patterns)
    patterns.each_with_index do |pattern, i|
      found_index =
        if pattern.is_a?(Regexp)
          lines.find_index {|line| line =~ pattern}
        else
          lines.find_index do |line|
            line.chomp == pattern.chomp
          end
        end
      unless found_index
        $stderr.puts "Lines:"
        $stderr.puts lines
        raise "A line matching #{pattern.inspect} (index #{i}) was not found."
      end
    end
  end

  ###########################################################################
  # Tests
  ###########################################################################

  it 'builds a C program with one source file' do
    test_dir('simple')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(File.exists?('build/e.1/simple.o')).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C program\n"
  end

  it "allows specifying a Builder object as the source to another build target" do
    test_dir("simple")
    result = run_rscons(rsconscript: "builder_as_source.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("simple.o")).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C program\n"
  end

  it 'prints commands as they are executed' do
    test_dir('simple')
    result = run_rscons(rsconscript: "command.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{gcc -c -o build/e.1/simple.o -MMD -MF build/e.1/simple.mf simple.c},
      %r{gcc -o simple.exe build/e.1/simple.o},
    ])
  end

  it 'prints short representations of the commands being executed' do
    test_dir('header')
    result = run_rscons
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{Compiling header.c},
      %r{Linking header.exe},
    ])
  end

  it 'builds a C program with one source file and one header file' do
    test_dir('header')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(File.exists?('build/e.1/header.o')).to be_truthy
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
    verify_lines(lines(result.stdout), [
      %r{Compiling header.c},
      %r{Linking header.exe},
    ])
    expect(`./header.exe`).to eq "The value is 2\n"
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""
  end

  it "does not rebuild a C module when only the file's timestamp has changed" do
    test_dir('header')
    result = run_rscons
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{Compiling header.c},
      %r{Linking header.exe},
    ])
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
    verify_lines(lines(result.stdout), [
      %r{gcc -c -o build/e.1/simple.o -MMD -MF build/e.1/simple.mf simple.c},
      %r{gcc -o simple.exe build/e.1/simple.o},
    ])
    result = run_rscons(rsconscript: "link_flag_change.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{gcc -o simple.exe build/e.1/simple.o -Llibdir},
    ])
  end

  it "supports barriers and prevents parallelizing builders across them" do
    test_dir "simple"
    result = run_rscons(rsconscript: "barrier.rb", rscons_args: %w[-j 3])
    expect(result.stderr).to eq ""
    slines = lines(result.stdout).select {|line| line =~ /T\d/}
    expect(slines).to eq [
      "[1/6] ThreadedTestBuilder T3",
      "[2/6] ThreadedTestBuilder T2",
      "[3/6] ThreadedTestBuilder T1",
      "T1 finished",
      "T2 finished",
      "T3 finished",
      "[4/6] ThreadedTestBuilder T6",
      "[5/6] ThreadedTestBuilder T5",
      "[6/6] ThreadedTestBuilder T4",
      "T4 finished",
      "T5 finished",
      "T6 finished",
    ]
  end

  it "expands target and source paths starting with ^/ to be relative to the build root" do
    test_dir("typical")
    result = run_rscons(rsconscript: "carat.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{gcc -c -o build/e.1/one.o -MMD -MF build/e.1/one.mf -Isrc -Isrc/one -Isrc/two build/e.1/one.c},
      %r{gcc -c -o build/e.1/src/two/two.o -MMD -MF build/e.1/src/two/two.mf -Isrc -Isrc/one -Isrc/two src/two/two.c},
      %r{gcc -o program.exe build/e.1/src/two/two.o build/e.1/one.o},
    ])
  end

  it 'supports simple builders' do
    test_dir('json_to_yaml')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(File.exists?('foo.yml')).to be_truthy
    expect(IO.read('foo.yml')).to eq("---\nkey: value\n")
  end

  it "raises an error when a side-effect file is registered for a build target that is not registered" do
    test_dir "simple"
    result = run_rscons(rsconscript: "error_produces_nonexistent_target.rb")
    expect(result.stderr).to match /Could not find a registered build target "foo"/
  end

  context "clean operation" do
    it 'cleans built files' do
      test_dir("simple")
      result = run_rscons
      expect(result.stderr).to eq ""
      expect(`./simple.exe`).to match /This is a simple C program/
      expect(File.exists?('build/e.1/simple.o')).to be_truthy
      result = run_rscons(op: %w[clean])
      expect(File.exists?('build/e.1/simple.o')).to be_falsey
      expect(File.exists?('build/e.1')).to be_falsey
      expect(File.exists?('simple.exe')).to be_falsey
      expect(File.exists?('simple.c')).to be_truthy
    end

    it 'does not clean created directories if other non-rscons-generated files reside there' do
      test_dir("simple")
      result = run_rscons
      expect(result.stderr).to eq ""
      expect(`./simple.exe`).to match /This is a simple C program/
      expect(File.exists?('build/e.1/simple.o')).to be_truthy
      File.open('build/e.1/dum', 'w') { |fh| fh.puts "dum" }
      result = run_rscons(op: %w[clean])
      expect(File.exists?('build/e.1')).to be_truthy
      expect(File.exists?('build/e.1/dum')).to be_truthy
    end

    it "removes built files but not installed files" do
      test_dir "typical"

      Dir.mktmpdir do |prefix|
        result = run_rscons(rsconscript: "install.rb", op: %W[configure --prefix=#{prefix}])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %W[install])
        expect(result.stderr).to eq ""
        expect(File.exists?("#{prefix}/bin/program.exe")).to be_truthy
        expect(File.exists?("build/e.1/src/one/one.o")).to be_truthy

        result = run_rscons(rsconscript: "install.rb", op: %W[clean])
        expect(result.stderr).to eq ""
        expect(File.exists?("#{prefix}/bin/program.exe")).to be_truthy
        expect(File.exists?("build/e.1/src/one/one.o")).to be_falsey
      end
    end

    it "does not remove install cache entries" do
      test_dir "typical"

      Dir.mktmpdir do |prefix|
        result = run_rscons(rsconscript: "install.rb", op: %W[configure --prefix=#{prefix}])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %W[install])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %W[clean])
        expect(result.stderr).to eq ""
        expect(File.exists?("#{prefix}/bin/program.exe")).to be_truthy
        expect(File.exists?("build/e.1/src/one/one.o")).to be_falsey

        result = run_rscons(rsconscript: "install.rb", op: %W[uninstall -v])
        expect(result.stderr).to eq ""
        expect(result.stdout).to match %r{Removing #{prefix}/bin/program.exe}
        expect(Dir.entries(prefix)).to match_array %w[. ..]
      end
    end
  end

  it 'allows Ruby classes as custom builders to be used to construct files' do
    test_dir('custom_builder')
    result = run_rscons
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{Compiling program.c},
      %r{Linking program.exe},
    ])
    expect(File.exists?('inc.h')).to be_truthy
    expect(`./program.exe`).to eq "The value is 5678\n"
  end

  it 'supports custom builders with multiple targets' do
    test_dir('custom_builder')
    result = run_rscons(rsconscript: "multiple_targets.rb")
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    verify_lines(slines, [
      %r{CHGen inc.c},
      %r{Compiling program.c},
      %r{Compiling inc.c},
      %r{Linking program.exe},
    ])
    expect(File.exists?("inc.c")).to be_truthy
    expect(File.exists?("inc.h")).to be_truthy
    expect(`./program.exe`).to eq "The value is 42\n"

    File.open("inc.c", "w") {|fh| fh.puts "int THE_VALUE = 33;"}
    result = run_rscons(rsconscript: "multiple_targets.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [%r{CHGen inc.c}])
    expect(`./program.exe`).to eq "The value is 42\n"
  end

  it 'raises an error when a custom builder returns an invalid value from #run' do
    test_dir("custom_builder")
    result = run_rscons(rsconscript: "error_run_return_value.rb")
    expect(result.stderr).to match /Unrecognized MyBuilder builder return value: "hi"/
    expect(result.status).to_not eq 0
  end

  it 'raises an error when a custom builder returns an invalid value using Builder#wait_for' do
    test_dir("custom_builder")
    result = run_rscons(rsconscript: "error_wait_for.rb")
    expect(result.stderr).to match /Unrecognized MyBuilder builder return item: 1/
    expect(result.status).to_not eq 0
  end

  it 'supports a Builder waiting for a custom Thread object' do
    test_dir "custom_builder"
    result = run_rscons(rsconscript: "wait_for_thread.rb")
    expect(result.stderr).to eq ""
    expect(result.status).to eq 0
    verify_lines(lines(result.stdout), [%r{MyBuilder foo}])
    expect(File.exists?("foo")).to be_truthy
  end

  it 'supports a Builder waiting for another Builder' do
    test_dir "simple"
    result = run_rscons(rsconscript: "builder_wait_for_builder.rb")
    expect(result.stderr).to eq ""
    expect(result.status).to eq 0
    verify_lines(lines(result.stdout), [%r{MyObject simple.o}])
    expect(File.exists?("simple.o")).to be_truthy
    expect(File.exists?("simple.exe")).to be_truthy
  end

  it 'allows cloning Environment objects' do
    test_dir('clone_env')
    result = run_rscons
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{gcc -c -o build/e.1/src/program.o -MMD -MF build/e.1/src/program.mf '-DSTRING="Debug Version"' -O2 src/program.c},
      %r{gcc -o program-debug.exe build/e.1/src/program.o},
      %r{gcc -c -o build/e.2/src/program.o -MMD -MF build/e.2/src/program.mf '-DSTRING="Release Version"' -O2 src/program.c},
      %r{gcc -o program-release.exe build/e.2/src/program.o},
    ])
  end

  it 'clones all attributes of an Environment object by default' do
    test_dir('clone_env')
    result = run_rscons(rsconscript: "clone_all.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{gcc -c -o build/e.1/src/program.o -MMD -MF build/e.1/src/program.mf -DSTRING="Hello" -O2 src/program.c},
      %r{post build/e.1/src/program.o},
      %r{gcc -o program.exe build/e.1/src/program.o},
      %r{post program.exe},
      %r{post build/e.2/src/program.o},
      %r{gcc -o program2.exe build/e.2/src/program.o},
      %r{post program2.exe},
    ])
  end

  it 'builds a C++ program with one source file' do
    test_dir('simple_cc')
    result = run_rscons
    expect(result.stderr).to eq ""
    expect(File.exists?('build/e.1/simple.o')).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C++ program\n"
  end

  it "links with the C++ linker when object files were built from C++ sources" do
    test_dir("simple_cc")
    result = run_rscons(rsconscript: "link_objects.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("simple.o")).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C++ program\n"
  end

  it 'allows overriding construction variables for individual builder calls' do
    test_dir('two_sources')
    result = run_rscons
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{gcc -c -o one.o -MMD -MF one.mf -DONE one.c},
      %r{gcc -c -o build/e.1/two.o -MMD -MF build/e.1/two.mf two.c},
      %r{gcc -o two_sources.exe one.o build/e.1/two.o},
    ])
    expect(File.exists?("two_sources.exe")).to be_truthy
    expect(`./two_sources.exe`).to eq "This is a C program with two sources.\n"
  end

  it 'builds a static library archive' do
    test_dir('library')
    result = run_rscons
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{gcc -c -o build/e.1/one.o -MMD -MF build/e.1/one.mf -Dmake_lib one.c},
      %r{gcc -c -o build/e.1/two.o -MMD -MF build/e.1/two.mf -Dmake_lib two.c},
      %r{ar rcs lib.a build/e.1/one.o build/e.1/two.o},
      %r{gcc -c -o build/e.1/three.o -MMD -MF build/e.1/three.mf three.c},
      %r{gcc -o library.exe lib.a build/e.1/three.o},
    ])
    expect(File.exists?("library.exe")).to be_truthy
    expect(`ar t lib.a`).to eq "one.o\ntwo.o\n"
  end

  it 'supports build hooks to override construction variables' do
    test_dir("typical")
    result = run_rscons(rsconscript: "build_hooks.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{gcc -c -o build/e.1/src/one/one.o -MMD -MF build/e.1/src/one/one.mf -Isrc/one -Isrc/two -O1 src/one/one.c},
      %r{gcc -c -o build/e.1/src/two/two.o -MMD -MF build/e.1/src/two/two.mf -Isrc/one -Isrc/two -O2 src/two/two.c},
      %r{gcc -o build_hook.exe build/e.1/src/one/one.o build/e.1/src/two/two.o},
    ])
    expect(`./build_hook.exe`).to eq "Hello from two()\n"
  end

  it 'supports build hooks to override the entire vars hash' do
    test_dir("typical")
    result = run_rscons(rsconscript: "build_hooks_override_vars.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{gcc -c -o one.o -MMD -MF one.mf -Isrc -Isrc/one -Isrc/two -O1 src/two/two.c},
      %r{gcc -c -o two.o -MMD -MF two.mf -Isrc -Isrc/one -Isrc/two -O2 src/two/two.c},
    ])
    expect(File.exists?('one.o')).to be_truthy
    expect(File.exists?('two.o')).to be_truthy
  end

  it 'rebuilds when user-specified dependencies change' do
    test_dir('simple')

    File.open("program.ld", "w") {|fh| fh.puts("1")}
    result = run_rscons(rsconscript: "user_dependencies.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{Compiling simple.c},
      %r{Linking simple.exe},
    ])
    expect(File.exists?('build/e.1/simple.o')).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C program\n"

    File.open("program.ld", "w") {|fh| fh.puts("2")}
    result = run_rscons(rsconscript: "user_dependencies.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [%r{Linking simple.exe}])

    File.unlink("program.ld")
    result = run_rscons(rsconscript: "user_dependencies.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [%r{Linking simple.exe}])

    result = run_rscons(rsconscript: "user_dependencies.rb")
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""
  end

  it "supports building D sources with gdc" do
    test_dir("d")
    result = run_rscons
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    verify_lines(slines, [%r{gdc -c -o build/e.1/main.o -MMD -MF build/e.1/main.mf main.d}])
    verify_lines(slines, [%r{gdc -c -o build/e.1/mod.o -MMD -MF build/e.1/mod.mf mod.d}])
    verify_lines(slines, [%r{gdc -o hello-d.exe build/e.1/main.o build/e.1/mod.o}])
    expect(`./hello-d.exe`.rstrip).to eq "Hello from D, value is 42!"
  end

  it "supports building D sources with ldc2" do
    test_dir("d")
    result = run_rscons(rsconscript: "build-ldc2.rb")
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    verify_lines(slines, [%r{ldc2 -c -of build/e.1/main.o(bj)? -deps=build/e.1/main.mf main.d}])
    verify_lines(slines, [%r{ldc2 -c -of build/e.1/mod.o(bj)? -deps=build/e.1/mod.mf mod.d}])
    verify_lines(slines, [%r{ldc2 -of hello-d.exe build/e.1/main.o(bj)? build/e.1/mod.o(bj)?}])
    expect(`./hello-d.exe`.rstrip).to eq "Hello from D, value is 42!"
  end

  it "rebuilds D modules with ldc2 when deep dependencies change" do
    test_dir("d")
    result = run_rscons(rsconscript: "build-ldc2.rb")
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    verify_lines(slines, [%r{ldc2 -c -of build/e.1/main.o(bj)? -deps=build/e.1/main.mf main.d}])
    verify_lines(slines, [%r{ldc2 -c -of build/e.1/mod.o(bj)? -deps=build/e.1/mod.mf mod.d}])
    verify_lines(slines, [%r{ldc2 -of hello-d.exe build/e.1/main.o(bj)? build/e.1/mod.o(bj)?}])
    expect(`./hello-d.exe`.rstrip).to eq "Hello from D, value is 42!"
    contents = File.read("mod.d", mode: "rb").sub("42", "33")
    File.open("mod.d", "wb") do |fh|
      fh.write(contents)
    end
    result = run_rscons(rsconscript: "build-ldc2.rb")
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    verify_lines(slines, [%r{ldc2 -c -of build/e.1/main.o(bj)? -deps=build/e.1/main.mf main.d}])
    verify_lines(slines, [%r{ldc2 -c -of build/e.1/mod.o(bj)? -deps=build/e.1/mod.mf mod.d}])
    verify_lines(slines, [%r{ldc2 -of hello-d.exe build/e.1/main.o(bj)? build/e.1/mod.o(bj)?}])
    expect(`./hello-d.exe`.rstrip).to eq "Hello from D, value is 33!"
  end

  unless ENV["omit_gdc_tests"]
    it "links with the D linker when object files were built from D sources" do
      test_dir("d")
      result = run_rscons(rsconscript: "link_objects.rb")
      expect(result.stderr).to eq ""
      expect(File.exists?("main.o")).to be_truthy
      expect(File.exists?("mod.o")).to be_truthy
      expect(`./hello-d.exe`.rstrip).to eq "Hello from D, value is 42!"
    end

    it "does dependency generation for D sources" do
      test_dir("d")
      result = run_rscons
      expect(result.stderr).to eq ""
      slines = lines(result.stdout)
      verify_lines(slines, [%r{gdc -c -o build/e.1/main.o -MMD -MF build/e.1/main.mf main.d}])
      verify_lines(slines, [%r{gdc -c -o build/e.1/mod.o -MMD -MF build/e.1/mod.mf mod.d}])
      verify_lines(slines, [%r{gdc -o hello-d.exe build/e.1/main.o build/e.1/mod.o}])
      expect(`./hello-d.exe`.rstrip).to eq "Hello from D, value is 42!"
      fcontents = File.read("mod.d", mode: "rb").sub("42", "33")
      File.open("mod.d", "wb") {|fh| fh.write(fcontents)}
      result = run_rscons
      expect(result.stderr).to eq ""
      slines = lines(result.stdout)
      verify_lines(slines, [%r{gdc -c -o build/e.1/main.o -MMD -MF build/e.1/main.mf main.d}])
      verify_lines(slines, [%r{gdc -c -o build/e.1/mod.o -MMD -MF build/e.1/mod.mf mod.d}])
      verify_lines(slines, [%r{gdc -o hello-d.exe build/e.1/main.o build/e.1/mod.o}])
      expect(`./hello-d.exe`.rstrip).to eq "Hello from D, value is 33!"
    end

    it "creates shared libraries using D" do
      test_dir("shared_library")

      result = run_rscons(rsconscript: "shared_library_d.rb")
      expect(result.stderr).to eq ""
      slines = lines(result.stdout)
      if RUBY_PLATFORM =~ /mingw/
        verify_lines(slines, [%r{Linking mine.dll}])
      else
        verify_lines(slines, [%r{Linking libmine.so}])
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

  it "supports invoking builders with no sources" do
    test_dir("simple")
    result = run_rscons(rsconscript: "builder_no_sources.rb")
    expect(result.stderr).to eq ""
  end

  it "expands construction variables in builder target and sources before invoking the builder" do
    test_dir('custom_builder')
    result = run_rscons(rsconscript: "cvar_expansion.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{Compiling program.c},
      %r{Linking program.exe},
    ])
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
    expect(File.exists?("build/e.1/simple.o")).to be_truthy
    expect(File.exists?("build/e.1/simple.o.txt")).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C program\n"
  end

  it "supports multiple values for CXXSUFFIX" do
    test_dir("simple_cc")
    File.open("other.cccc", "w") {|fh| fh.puts}
    result = run_rscons(rsconscript: "cxxsuffix.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("build/e.1/simple.o")).to be_truthy
    expect(File.exists?("build/e.1/other.o")).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C++ program\n"
  end

  it "supports multiple values for CSUFFIX" do
    test_dir("typical")
    FileUtils.mv("src/one/one.c", "src/one/one.yargh")
    result = run_rscons(rsconscript: "csuffix.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("build/e.1/src/one/one.o")).to be_truthy
    expect(File.exists?("build/e.1/src/two/two.o")).to be_truthy
    expect(`./program.exe`).to eq "Hello from two()\n"
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
    verify_lines(lines(result.stdout), [
      %r{Compiling one.c},
      %r{Compiling two.c},
      %r{Assembling one.ssss},
      %r{Assembling two.sss},
      %r{Linking two_sources.exe},
    ])
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
    verify_lines(lines(result.stdout), [%r{Preprocessing foo.h => pp}])
    expect(File.read("pp")).to match(%r{xyz42abc}m)

    result = run_rscons
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""

    File.open("bar.h", "w") do |fh|
      fh.puts "#define BAR abc88xyz"
    end
    result = run_rscons
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [%r{Preprocessing foo.h => pp}])
    expect(File.read("pp")).to match(%r{abc88xyz}m)
  end

  it "allows construction variable references which expand to arrays in sources of a build target" do
    test_dir("simple")
    result = run_rscons(rsconscript: "cvar_array.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("build/e.1/simple.o")).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C program\n"
  end

  it "supports registering multiple build targets with the same target path" do
    test_dir("typical")
    result = run_rscons(rsconscript: "multiple_targets_same_name.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("one.o")).to be_truthy
    verify_lines(lines(result.stdout), [
      %r{Compiling src/one/one.c},
      %r{Compiling src/two/two.c},
    ])
  end

  it "expands target and source paths when builders are registered in build hooks" do
    test_dir("typical")
    result = run_rscons(rsconscript: "post_build_hook_expansion.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("one.o")).to be_truthy
    expect(File.exists?("two.o")).to be_truthy
    verify_lines(lines(result.stdout), [
      %r{Compiling src/one/one.c},
      %r{Compiling src/two/two.c},
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
    verify_lines(lines(result.stdout), [
      %r{Compiling two.c},
    ])
  end

  it "allows overriding PROGSUFFIX" do
    test_dir("simple")
    result = run_rscons(rsconscript: "progsuffix.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{Compiling simple.c},
      %r{Linking simple.out},
    ])
  end

  it "does not use PROGSUFFIX when the Program target name expands to a value already containing an extension" do
    test_dir("simple")
    result = run_rscons(rsconscript: "progsuffix2.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{Compiling simple.c},
      %r{Linking simple.out},
    ])
  end

  it "allows overriding PROGSUFFIX from extra vars passed in to the builder" do
    test_dir("simple")
    result = run_rscons(rsconscript: "progsuffix3.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [
      %r{Compiling simple.c},
      %r{Linking simple.xyz},
    ])
  end

  it "creates object files under the build root for absolute source paths" do
    test_dir("simple")
    result = run_rscons(rsconscript: "absolute_source_path.rb")
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    verify_lines(slines, [%r{build/e.1/.*/abs\.o$}])
    verify_lines(slines, [%r{\babs.exe\b}])
  end

  it "creates shared libraries" do
    test_dir("shared_library")

    result = run_rscons
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    if RUBY_PLATFORM =~ /mingw/
      verify_lines(slines, [%r{Linking mine.dll}])
      expect(File.exists?("mine.dll")).to be_truthy
    else
      verify_lines(slines, [%r{Linking libmine.so}])
      expect(File.exists?("libmine.so")).to be_truthy
    end

    result = run_rscons
    expect(result.stderr).to eq ""
    expect(result.stdout).to eq ""

    ld_library_path_prefix = (RUBY_PLATFORM =~ /mingw/ ? "" : "LD_LIBRARY_PATH=. ")
    expect(`#{ld_library_path_prefix}./test-shared.exe`).to match /Hi from one/
    expect(`./test-static.exe`).to match /Hi from one/
  end

  it "creates shared libraries using assembly" do
    test_dir("shared_library")

    result = run_rscons(rsconscript: "shared_library_as.rb")
    expect(result.stderr).to eq ""
    expect(File.exists?("file.S")).to be_truthy
  end

  it "creates shared libraries using C++" do
    test_dir("shared_library")

    result = run_rscons(rsconscript: "shared_library_cxx.rb")
    expect(result.stderr).to eq ""
    slines = lines(result.stdout)
    if RUBY_PLATFORM =~ /mingw/
      verify_lines(slines, [%r{Linking mine.dll}])
    else
      verify_lines(slines, [%r{Linking libmine.so}])
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
    verify_lines(lines(result.stdout), [/165/])
  end

  it "prints a builder's short description with 'command' echo mode if there is no command" do
    test_dir("typical")

    result = run_rscons(rsconscript: "echo_command_ruby_builder.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [%r{Copy echo_command_ruby_builder.rb => copy.rb}])
  end

  it "supports a string for a builder's echoed 'command' with Environment#print_builder_run_message" do
    test_dir("typical")

    result = run_rscons(rsconscript: "echo_command_string.rb")
    expect(result.stderr).to eq ""
    verify_lines(lines(result.stdout), [%r{MyBuilder foo command}])
  end

  it "stores the failed command for later display with -F command line option" do
    test_dir("simple")

    File.open("simple.c", "wb") do |fh|
      fh.write("foo")
    end

    result = run_rscons
    expect(result.stderr).to match /Failed to build/
    expect(result.stderr).to match /^Use.*-F.*to view the failed command log/
    expect(result.status).to_not eq 0

    result = run_rscons(rscons_args: %w[-F])
    expect(result.stderr).to eq ""
    expect(result.stdout).to match %r{Failed command \(1/1\):}
    expect(result.stdout).to match %r{^gcc -}
    expect(result.status).to eq 0
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

  context "CFile builder" do
    it "builds a .c file using flex and bison" do
      test_dir("cfile")

      result = run_rscons
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{Generating lexer from lexer.l => lexer.c},
        %r{Generating parser from parser.y => parser.c},
      ])

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
      verify_lines(lines(result.stdout), [%r{BuildIt simple.exe}])
      expect(`./simple.exe`).to eq "This is a simple C program\n"

      result = run_rscons(rsconscript: "command_builder.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""
    end

    it "allows redirecting standard output to a file" do
      test_dir("simple")

      result = run_rscons(rsconscript: "command_redirect.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{Compiling simple.c},
        %r{My Disassemble simple.txt},
      ])
      expect(File.read("simple.txt")).to match /Disassembly of section .text:/
    end
  end

  context "Directory builder" do
    it "creates the requested directory" do
      test_dir("simple")
      result = run_rscons(rsconscript: "directory.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{Creating directory teh_dir}])
      expect(File.directory?("teh_dir")).to be_truthy
    end

    it "succeeds when the requested directory already exists" do
      test_dir("simple")
      FileUtils.mkdir("teh_dir")
      result = run_rscons(rsconscript: "directory.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to_not include a_string_matching /Creating directory/
      expect(File.directory?("teh_dir")).to be_truthy
    end

    it "fails when the target path is a file" do
      test_dir("simple")
      FileUtils.touch("teh_dir")
      result = run_rscons(rsconscript: "directory.rb")
      expect(result.stderr).to match %r{Error: `teh_dir' already exists and is not a directory}
    end
  end

  context "Copy builder" do
    it "copies a file to the target file name" do
      test_dir("typical")

      result = run_rscons(rsconscript: "copy.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{Copy copy.rb => inst.exe}])

      result = run_rscons(rsconscript: "copy.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""

      expect(File.exists?("inst.exe")).to be_truthy
      expect(File.read("inst.exe", mode: "rb")).to eq(File.read("copy.rb", mode: "rb"))

      FileUtils.rm("inst.exe")
      result = run_rscons(rsconscript: "copy.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{Copy copy.rb => inst.exe}])
    end

    it "copies multiple files to the target directory name" do
      test_dir("typical")

      result = run_rscons(rsconscript: "copy_multiple.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{Copy copy.rb \(\+1\) => dest}])

      result = run_rscons(rsconscript: "copy_multiple.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""

      expect(Dir.exists?("dest")).to be_truthy
      expect(File.exists?("dest/copy.rb")).to be_truthy
      expect(File.exists?("dest/copy_multiple.rb")).to be_truthy

      FileUtils.rm_rf("dest")
      result = run_rscons(rsconscript: "copy_multiple.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{Copy copy.rb \(\+1\) => dest}])
    end

    it "copies a file to the target directory name" do
      test_dir("typical")

      result = run_rscons(rsconscript: "copy_directory.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{Copy copy_directory.rb => copy}])
      expect(File.exists?("copy/copy_directory.rb")).to be_truthy
      expect(File.read("copy/copy_directory.rb", mode: "rb")).to eq(File.read("copy_directory.rb", mode: "rb"))

      result = run_rscons(rsconscript: "copy_directory.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""
    end

    it "copies a directory to the non-existent target directory name" do
      test_dir("typical")
      result = run_rscons(rsconscript: "copy_directory.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{Copy src => noexist/src}])
      %w[src/one/one.c src/two/two.c src/two/two.h].each do |f|
        expect(File.exists?("noexist/#{f}")).to be_truthy
        expect(File.read("noexist/#{f}", mode: "rb")).to eq(File.read(f, mode: "rb"))
      end
    end

    it "copies a directory to the existent target directory name" do
      test_dir("typical")
      result = run_rscons(rsconscript: "copy_directory.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{Copy src => exist/src}])
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
      verify_lines(lines(result.stdout), [
        %r{Compiling simple.c},
        %r{Linking simple.exe},
        %r{Checker simple.exe},
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
      verify_lines(lines(result.stdout), [
        %r{Checker simple.exe},
      ])
    end
  end

  context "Environment#clear_targets" do
    it "clears registered targets" do
      test_dir("simple")
      result = run_rscons(rsconscript: "clear_targets.rb")
      expect(result.stderr).to eq ""
      expect(lines(result.stdout)).to_not include a_string_matching %r{Linking}
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
      verify_lines(lines(result.stdout), [
        %r{Compiling simple.c},
        %r{Linking simple.exe},
      ])

      result = run_rscons(rsconscript: "cache_command_change.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{Linking simple.exe},
      ])
    end

    it "forces a build when there is a new dependency" do
      test_dir("simple")

      result = run_rscons(rsconscript: "cache_new_dep1.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{Compiling simple.c},
        %r{Linking simple.exe},
      ])

      result = run_rscons(rsconscript: "cache_new_dep2.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{Linking simple.exe},
      ])
    end

    it "forces a build when a dependency's checksum has changed" do
      test_dir("simple")

      result = run_rscons(rsconscript: "cache_dep_checksum_change.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{Copy simple.c => simple.copy}])
      File.open("simple.c", "wb") do |fh|
        fh.write("hi")
      end

      result = run_rscons(rsconscript: "cache_dep_checksum_change.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{Copy simple.c => simple.copy}])
    end

    it "forces a rebuild with strict_deps=true when dependency order changes" do
      test_dir("two_sources")

      File.open("sources", "wb") do |fh|
        fh.write("one.o two.o")
      end
      result = run_rscons(rsconscript: "cache_strict_deps.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{gcc -o program.exe one.o two.o}])

      result = run_rscons(rsconscript: "cache_strict_deps.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""

      File.open("sources", "wb") do |fh|
        fh.write("two.o one.o")
      end
      result = run_rscons(rsconscript: "cache_strict_deps.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{gcc -o program.exe one.o two.o}])
    end

    it "forces a rebuild when there is a new user dependency" do
      test_dir("simple")

      File.open("foo", "wb") {|fh| fh.write("hi")}
      File.open("user_deps", "wb") {|fh| fh.write("")}
      result = run_rscons(rsconscript: "cache_user_dep.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{Compiling simple.c},
        %r{Linking simple.exe},
      ])

      File.open("user_deps", "wb") {|fh| fh.write("foo")}
      result = run_rscons(rsconscript: "cache_user_dep.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{Linking simple.exe},
      ])
    end

    it "forces a rebuild when a user dependency file checksum has changed" do
      test_dir("simple")

      File.open("foo", "wb") {|fh| fh.write("hi")}
      File.open("user_deps", "wb") {|fh| fh.write("foo")}
      result = run_rscons(rsconscript: "cache_user_dep.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{Compiling simple.c},
        %r{Linking simple.exe},
      ])

      result = run_rscons(rsconscript: "cache_user_dep.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to eq ""

      File.open("foo", "wb") {|fh| fh.write("hi2")}
      result = run_rscons(rsconscript: "cache_user_dep.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{Linking simple.exe},
      ])
    end

    it "allows a VarSet to be passed in as the command parameter" do
      test_dir("simple")
      result = run_rscons(rsconscript: "cache_varset.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{TestBuilder foo},
      ])
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
      verify_lines(lines(result.stdout), [
        %r{gcc -c -o simple.o -Dfoobar simple.c},
      ])
    end

    it "allows overriding DEPFILESUFFIX construction variable" do
      test_dir("simple")
      result = run_rscons(rsconscript: "override_depfilesuffix.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{gcc -c -o simple.o -MMD -MF simple.deppy simple.c},
      ])
    end

    it "raises an error when given a source file with an unknown suffix" do
      test_dir("simple")
      result = run_rscons(rsconscript: "error_unknown_suffix.rb")
      expect(result.stderr).to match /Unknown input file type: "foo.xyz"/
    end
  end

  context "SharedObject builder" do
    it "raises an error when given a source file with an unknown suffix" do
      test_dir("shared_library")
      result = run_rscons(rsconscript: "error_unknown_suffix.rb")
      expect(result.stderr).to match /Unknown input file type: "foo.xyz"/
    end
  end

  context "Library builder" do
    it "allows overriding ARCMD construction variable" do
      test_dir("library")
      result = run_rscons(rsconscript: "override_arcmd.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [%r{ar rcf lib.a build/e.1/one.o build/e.1/three.o build/e.1/two.o}])
    end

    it "allows passing object files as sources" do
      test_dir("library")
      result = run_rscons(rsconscript: "library_from_object.rb")
      expect(result.stderr).to eq ""
      expect(File.exists?("two.o")).to be_truthy
      verify_lines(lines(result.stdout), [%r{Building static library archive lib.a}])
    end
  end

  context "SharedLibrary builder" do
    it "allows explicitly specifying SHLD construction variable value" do
      test_dir("shared_library")

      result = run_rscons(rsconscript: "shared_library_set_shld.rb")
      expect(result.stderr).to eq ""
      slines = lines(result.stdout)
      if RUBY_PLATFORM =~ /mingw/
        verify_lines(slines, [%r{Linking mine.dll}])
      else
        verify_lines(slines, [%r{Linking libmine.so}])
      end
    end

    it "allows passing object files as sources" do
      test_dir "shared_library"
      result = run_rscons(rsconscript: "shared_library_from_object.rb")
      expect(result.stderr).to eq ""
      expect(File.exists?("one.o"))
    end
  end

  context "multi-threading" do
    it "waits for subcommands in threads for builders that support threaded commands" do
      test_dir("simple")
      start_time = Time.new
      result = run_rscons(rsconscript: "threading.rb", rscons_args: %w[-j 4])
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{ThreadedTestBuilder a},
        %r{ThreadedTestBuilder b},
        %r{ThreadedTestBuilder c},
        %r{NonThreadedTestBuilder d},
      ])
      elapsed = Time.new - start_time
      expect(elapsed).to be < 4
    end

    it "allows the user to specify that a target be built after another" do
      test_dir("custom_builder")
      result = run_rscons(rsconscript: "build_after.rb", rscons_args: %w[-j 4])
      expect(result.stderr).to eq ""
    end

    it "allows the user to specify side-effect files produced by another builder with Builder#produces" do
      test_dir("custom_builder")
      result = run_rscons(rsconscript: "produces.rb", rscons_args: %w[-j 4])
      expect(result.stderr).to eq ""
      expect(File.exists?("copy_inc.h")).to be_truthy
    end

    it "allows the user to specify side-effect files produced by another builder with Environment#produces" do
      test_dir("custom_builder")
      result = run_rscons(rsconscript: "produces_env.rb", rscons_args: %w[-j 4])
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

    it "outputs an error for an unknown operation" do
      test_dir "simple"
      result = run_rscons(op: "unknownop")
      expect(result.stderr).to match /Unknown operation: unknownop/
      expect(result.status).to_not eq 0
    end

    it "displays usage and error message without a backtrace for an invalid CLI option" do
      test_dir "simple"
      result = run_rscons(rscons_args: %w[--xyz])
      expect(result.stderr).to_not match /Traceback/
      expect(result.stderr).to match /invalid option.*--xyz/
      expect(result.stderr).to match /Usage:/
      expect(result.status).to_not eq 0
    end

    it "displays usage and error message without a backtrace for an invalid CLI option to a valid subcommand" do
      test_dir "simple"
      result = run_rscons(op: %w[configure --xyz])
      expect(result.stderr).to_not match /Traceback/
      expect(result.stderr).to match /invalid option.*--xyz/
      expect(result.stderr).to match /Usage:/
      expect(result.status).to_not eq 0
    end
  end

  context "configure operation" do
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

      it "successfully tests a compiler with an unknown name" do
        test_dir "configure"
        create_exe "mycompiler", %[exec gcc "$@"]
        result = run_rscons(rsconscript: "check_c_compiler_custom.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for C compiler\.\.\. mycompiler/
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

      it "successfully tests a compiler with an unknown name" do
        test_dir "configure"
        create_exe "mycompiler", %[exec clang++ "$@"]
        result = run_rscons(rsconscript: "check_cxx_compiler_custom.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for C\+\+ compiler\.\.\. mycompiler/
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

      it "successfully tests a compiler with an unknown name that uses gdc-compatible options" do
        test_dir "configure"
        create_exe "mycompiler", %[exec gdc "$@"]
        result = run_rscons(rsconscript: "check_d_compiler_custom.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for D compiler\.\.\. mycompiler/
      end

      it "successfully tests a compiler with an unknown name that uses ldc2-compatible options" do
        test_dir "configure"
        create_exe "mycompiler", %[exec ldc2 "$@"]
        result = run_rscons(rsconscript: "check_d_compiler_custom.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for D compiler\.\.\. mycompiler/
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

      it "sets the specified define when the header is found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_c_header_success_set_define.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for C header 'string\.h'... found/
        result = run_rscons(rsconscript: "check_c_header_success_set_define.rb", op: "build")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /-DHAVE_STRING_H/
      end

      it "does not set the specified define when the header is not found" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_c_header_no_fail_set_define.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for C header 'not___found\.h'... not found/
        result = run_rscons(rsconscript: "check_c_header_no_fail_set_define.rb", op: "build")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to_not match /-DHAVE_/
      end

      it "modifies CPPPATH based on check_cpppath" do
        test_dir "configure"
        FileUtils.mkdir_p("usr1")
        FileUtils.mkdir_p("usr2")
        File.open("usr2/frobulous.h", "wb") do |fh|
          fh.puts("#define FOO 42")
        end
        result = run_rscons(rsconscript: "check_c_header_cpppath.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        result = run_rscons(rsconscript: "check_c_header_cpppath.rb", rscons_args: %w[-v])
        expect(result.stdout).to_not match %r{-I./usr1}
        expect(result.stdout).to match %r{-I./usr2}
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

      it "modifies CPPPATH based on check_cpppath" do
        test_dir "configure"
        FileUtils.mkdir_p("usr1")
        FileUtils.mkdir_p("usr2")
        File.open("usr2/frobulous.h", "wb") do |fh|
          fh.puts("#define FOO 42")
        end
        result = run_rscons(rsconscript: "check_cxx_header_cpppath.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        result = run_rscons(rsconscript: "check_cxx_header_cpppath.rb", rscons_args: %w[-v])
        expect(result.stdout).to_not match %r{-I./usr1}
        expect(result.stdout).to match %r{-I./usr2}
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

      it "modifies D_IMPORT_PATH based on check_d_import_path" do
        test_dir "configure"
        FileUtils.mkdir_p("usr1")
        FileUtils.mkdir_p("usr2")
        File.open("usr2/frobulous.d", "wb") do |fh|
          fh.puts("int foo = 42;")
        end
        result = run_rscons(rsconscript: "check_d_import_d_import_path.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        result = run_rscons(rsconscript: "check_d_import_d_import_path.rb", rscons_args: %w[-v])
        expect(result.stdout).to_not match %r{-I./usr1}
        expect(result.stdout).to match %r{-I./usr2}
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

      it "links against the checked library by default" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_lib_success.rb", op: "build")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for library 'm'... found/
        expect(result.stdout).to match /gcc.*-lm/
      end

      it "does not link against the checked library by default if :use is specified" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_lib_use.rb", op: "build")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for library 'm'... found/
        expect(result.stdout).to_not match /gcc.*test1.*-lm/
        expect(result.stdout).to match /gcc.*test2.*-lm/
      end

      it "does not link against the checked library if :use is set to false" do
        test_dir "configure"
        result = run_rscons(rsconscript: "check_lib_use_false.rb", op: "build")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match /Checking for library 'm'... found/
        expect(result.stdout).to_not match /-lm/
      end

      it "modifies LIBPATH based on check_libpath" do
        test_dir "configure"
        FileUtils.mkdir_p("usr1")
        FileUtils.mkdir_p("usr2")
        result = run_rscons(rsconscript: "check_lib_libpath1.rb")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        result = run_rscons(rsconscript: "check_lib_libpath2.rb", op: "configure")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        result = run_rscons(rsconscript: "check_lib_libpath2.rb")
        expect(result.stderr).to eq ""
        expect(result.status).to eq 0
        expect(result.stdout).to match %r{-L\./usr2}
        expect(result.stdout).to_not match %r{-L\./usr1}
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

      context "with non-existent PATH entries" do
        it "succeeds when the requested program is found" do
          test_dir "configure"
          result = run_rscons(rsconscript: "check_program_success.rb", op: "configure", path: "/foo/bar")
          expect(result.stderr).to eq ""
          expect(result.status).to eq 0
          expect(result.stdout).to match /Checking for program 'find'... .*find/
        end
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
      context "when passed a package" do
        it "stores flags and uses them during a build operation" do
          test_dir "configure"
          create_exe "pkg-config", "echo '-DMYPACKAGE'"
          result = run_rscons(rsconscript: "check_cfg_package.rb", op: "configure")
          expect(result.stderr).to eq ""
          expect(result.status).to eq 0
          expect(result.stdout).to match /Checking for package 'mypackage'\.\.\. found/
          result = run_rscons(rsconscript: "check_cfg_package.rb", op: "build")
          expect(result.stderr).to eq ""
          expect(result.status).to eq 0
          expect(result.stdout).to match /gcc.*-o.*\.o.*-DMYPACKAGE/
        end

        it "fails when the configure program given does not exist" do
          test_dir "configure"
          result = run_rscons(rsconscript: "check_cfg.rb", op: "configure")
          expect(result.stderr).to eq ""
          expect(result.status).to_not eq 0
          expect(result.stdout).to match /Checking 'my-config'\.\.\. not found/
        end

        it "does not use the flags found by default if :use is specified" do
          test_dir "configure"
          create_exe "pkg-config", "echo '-DMYPACKAGE'"
          result = run_rscons(rsconscript: "check_cfg_use.rb", op: "configure")
          expect(result.stderr).to eq ""
          expect(result.status).to eq 0
          expect(result.stdout).to match /Checking for package 'mypackage'\.\.\. found/
          result = run_rscons(rsconscript: "check_cfg_use.rb", op: "build")
          expect(result.stderr).to eq ""
          expect(result.status).to eq 0
          expect(result.stdout).to_not match /gcc.*-o.*myconfigtest1.*-DMYPACKAGE/
          expect(result.stdout).to match /gcc.*-o.*myconfigtest2.*-DMYPACKAGE/
        end
      end

      context "when passed a program" do
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

    context "custom_check" do
      context "when running a test command" do
        context "when executing the command fails" do
          context "when failures are fatal" do
            it "fails configuration with the correct error message" do
              test_dir "configure"
              create_exe "grep", "exit 4"
              result = run_rscons(rsconscript: "custom_config_check.rb", op: "configure")
              expect(result.stderr).to eq ""
              expect(result.stdout).to match /Checking 'grep' version\.\.\. error executing grep/
              expect(result.status).to_not eq 0
            end
          end

          context "when the custom logic indicates a failure" do
            it "fails configuration with the correct error message" do
              test_dir "configure"
              create_exe "grep", "echo 'grep (GNU grep) 1.1'"
              result = run_rscons(rsconscript: "custom_config_check.rb", op: "configure")
              expect(result.stderr).to eq ""
              expect(result.stdout).to match /Checking 'grep' version\.\.\. too old!/
              expect(result.status).to_not eq 0
            end
          end
        end

        context "when failures are not fatal" do
          context "when the custom logic indicates a failure" do
            it "displays the correct message and does not fail configuration" do
              test_dir "configure"
              create_exe "grep", "echo 'grep (GNU grep) 2.1'"
              result = run_rscons(rsconscript: "custom_config_check.rb", op: "configure")
              expect(result.stderr).to eq ""
              expect(result.stdout).to match /Checking 'grep' version\.\.\. we'll work with it but you should upgrade/
              expect(result.status).to eq 0
              result = run_rscons(rsconscript: "custom_config_check.rb", op: "build")
              expect(result.stderr).to eq ""
              expect(result.stdout).to match /GREP_WORKAROUND/
              expect(result.status).to eq 0
            end
          end
        end

        context "when the custom logic indicates success" do
          it "passes configuration with the correct message" do
            test_dir "configure"
            create_exe "grep", "echo 'grep (GNU grep) 3.0'"
            result = run_rscons(rsconscript: "custom_config_check.rb", op: "configure")
            expect(result.stderr).to eq ""
            expect(result.stdout).to match /Checking 'grep' version\.\.\. good!/
            expect(result.status).to eq 0
            result = run_rscons(rsconscript: "custom_config_check.rb", op: "build")
            expect(result.stderr).to eq ""
            expect(result.stdout).to match /GREP_FULL/
            expect(result.status).to eq 0
          end
        end
      end
    end

    it "does everything" do
      test_dir "configure"
      create_exe "pkg-config", "echo '-DMYPACKAGE'"
      result = run_rscons(rsconscript: "everything.rb", op: %w[configure --build=bb --prefix=/my/prefix])
      expect(result.stderr).to eq ""
      expect(result.status).to eq 0
      expect(result.stdout).to match /Configuring configure test\.\.\./
      expect(result.stdout).to match /Setting build directory\.\.\. bb/
      expect(result.stdout).to match %r{Setting prefix\.\.\. /my/prefix}
      expect(result.stdout).to match /Checking for C compiler\.\.\. gcc/
      expect(result.stdout).to match /Checking for C\+\+ compiler\.\.\. g\+\+/
      expect(result.stdout).to match /Checking for D compiler\.\.\. (gdc|ldc2)/
      expect(result.stdout).to match /Checking for package 'mypackage'\.\.\. found/
      expect(result.stdout).to match /Checking for C header 'stdio.h'\.\.\. found/
      expect(result.stdout).to match /Checking for C\+\+ header 'iostream'\.\.\. found/
      expect(result.stdout).to match /Checking for D import 'std.stdio'\.\.\. found/
      expect(result.stdout).to match /Checking for library 'm'\.\.\. found/
      expect(result.stdout).to match /Checking for program 'ls'\.\.\. .*ls/
    end

    it "aggregates multiple set_define's" do
      test_dir "configure"
      result = run_rscons(rsconscript: "multiple_set_define.rb", op: "configure")
      expect(result.stderr).to eq ""
      expect(result.status).to eq 0
      result = run_rscons(rsconscript: "multiple_set_define.rb", op: "build")
      expect(result.stderr).to eq ""
      expect(result.status).to eq 0
      expect(result.stdout).to match /gcc.*-o.*\.o.*-DHAVE_MATH_H\s.*-DHAVE_STDIO_H/
    end

    it "exits with an error if the project is not configured and a build is requested and autoconf is false" do
      test_dir "configure"
      result = run_rscons(rsconscript: "autoconf_false.rb")
      expect(result.stderr).to match /Project must be configured first, and autoconf is disabled/
      expect(result.status).to_not eq 0
    end

    it "exits with an error if configuration fails during autoconf" do
      test_dir "configure"
      result = run_rscons(rsconscript: "autoconf_fail.rb")
      expect(result.stdout).to match /Checking for C compiler\.\.\. not found/
      expect(result.status).to_not eq 0
    end

    it "exits with an error if configuration has not been performed before attempting to create an environment" do
      test_dir "configure"
      result = run_rscons(rsconscript: "error_env_construction_before_configure.rb")
      expect(result.stderr).to match /Project must be configured before creating an Environment/
      expect(result.status).to_not eq 0
    end

    it "does not rebuild after building with auto-configuration" do
      test_dir "configure"
      result = run_rscons(rsconscript: "autoconf_rebuild.rb")
      expect(result.stderr).to eq ""
      expect(result.status).to eq 0
      expect(File.exists?("simple.exe")).to be_truthy
      result = run_rscons(rsconscript: "autoconf_rebuild.rb")
      expect(result.stderr).to eq ""
      expect(result.status).to eq 0
      expect(result.stdout).to eq ""
    end
  end

  context "distclean" do
    it "removes built files and the build directory" do
      test_dir "simple"
      result = run_rscons(rsconscript: "distclean.rb")
      expect(result.stderr).to eq ""
      expect(result.status).to eq 0
      expect(File.exists?("simple.o")).to be_truthy
      expect(File.exists?("build")).to be_truthy
      result = run_rscons(rsconscript: "distclean.rb", op: "distclean")
      expect(result.stderr).to eq ""
      expect(result.status).to eq 0
      expect(File.exists?("simple.o")).to be_falsey
      expect(File.exists?("build")).to be_falsey
      expect(File.exists?(Rscons::Cache::CACHE_FILE)).to be_falsey
    end
  end

  context "verbose option" do
    it "does not echo commands when verbose options not given" do
      test_dir('simple')
      result = run_rscons
      expect(result.stderr).to eq ""
      expect(result.stdout).to match /Compiling.*simple\.c/
    end

    it "echoes commands by default with -v" do
      test_dir('simple')
      result = run_rscons(rscons_args: %w[-v])
      expect(result.stderr).to eq ""
      expect(result.stdout).to match /gcc.*-o.*simple/
    end

    it "echoes commands by default with --verbose" do
      test_dir('simple')
      result = run_rscons(rscons_args: %w[--verbose])
      expect(result.stderr).to eq ""
      expect(result.stdout).to match /gcc.*-o.*simple/
    end

    it "echoes commands by default with -v after build operation" do
      test_dir('simple')
      result = run_rscons(op: %w[build -v])
      expect(result.stderr).to eq ""
      expect(result.stdout).to match /gcc.*-o.*simple/
    end

    it "prints operation start time" do
      test_dir("simple")
      result = run_rscons(rscons_args: %w[-v])
      expect(result.stderr).to eq ""
      expect(result.stdout).to match /Starting 'configure' at/
      expect(result.stdout).to match /Starting 'build' at/
      expect(result.stdout).to match /'build' complete at/
      expect(result.stdout).to_not match /'configure' complete at/
    end
  end

  context "direct mode" do
    it "allows calling Program builder in direct mode and passes all sources to the C compiler" do
      test_dir("direct")

      result = run_rscons(rsconscript: "c_program.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to match %r{Compiling/Linking}
      expect(File.exists?("test.exe")).to be_truthy
      expect(`./test.exe`).to match /three/

      result = run_rscons(rsconscript: "c_program.rb")
      expect(result.stdout).to eq ""

      three_h = File.read("three.h", mode: "rb")
      File.open("three.h", "wb") do |fh|
        fh.write(three_h)
        fh.puts("#define FOO 42")
      end
      result = run_rscons(rsconscript: "c_program.rb")
      expect(result.stdout).to match %r{Compiling/Linking}
    end

    it "allows calling SharedLibrary builder in direct mode and passes all sources to the C compiler" do
      test_dir("direct")

      result = run_rscons(rsconscript: "c_shared_library.rb")
      expect(result.stderr).to eq ""
      expect(result.stdout).to match %r{Compiling/Linking}
      expect(File.exists?("test.exe")).to be_truthy
      ld_library_path_prefix = (RUBY_PLATFORM =~ /mingw/ ? "" : "LD_LIBRARY_PATH=. ")
      expect(`#{ld_library_path_prefix}./test.exe`).to match /three/

      result = run_rscons(rsconscript: "c_shared_library.rb")
      expect(result.stdout).to eq ""

      three_h = File.read("three.h", mode: "rb")
      File.open("three.h", "wb") do |fh|
        fh.write(three_h)
        fh.puts("#define FOO 42")
      end
      result = run_rscons(rsconscript: "c_shared_library.rb")
      expect(result.stdout).to match %r{Compiling/Linking}
    end
  end

  context "install operation" do
    it "invokes a configure operation if the project is not yet configured" do
      test_dir "typical"

      result = run_rscons(rsconscript: "install.rb", op: %W[install])
      expect(result.stdout).to match /Configuring install_test/
    end

    it "invokes a build operation" do
      test_dir "typical"

      Dir.mktmpdir do |prefix|
        result = run_rscons(rsconscript: "install.rb", op: %W[configure --prefix=#{prefix}])
        expect(result.stderr).to eq ""
        result = run_rscons(rsconscript: "install.rb", op: %W[install])
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Compiling/
        expect(result.stdout).to match /Linking/
      end
    end

    it "installs the requested directories and files" do
      test_dir "typical"

      Dir.mktmpdir do |prefix|
        result = run_rscons(rsconscript: "install.rb", op: %W[configure --prefix=#{prefix}])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %W[install])
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Creating directory/
        expect(result.stdout).to match /Install install.rb =>/
        expect(result.stdout).to match /Install src =>/
        expect(Dir.entries(prefix)).to match_array %w[. .. bin src share mult]
        expect(File.directory?("#{prefix}/bin")).to be_truthy
        expect(File.directory?("#{prefix}/src")).to be_truthy
        expect(File.directory?("#{prefix}/share")).to be_truthy
        expect(File.exists?("#{prefix}/bin/program.exe")).to be_truthy
        expect(File.exists?("#{prefix}/src/one/one.c")).to be_truthy
        expect(File.exists?("#{prefix}/share/proj/install.rb")).to be_truthy
        expect(File.exists?("#{prefix}/mult/install.rb")).to be_truthy
        expect(File.exists?("#{prefix}/mult/copy.rb")).to be_truthy

        result = run_rscons(rsconscript: "install.rb", op: %W[install])
        expect(result.stderr).to eq ""
        expect(result.stdout).to eq ""
      end
    end

    it "does not install when only a build is performed" do
      test_dir "typical"

      Dir.mktmpdir do |prefix|
        result = run_rscons(rsconscript: "install.rb", op: %W[configure --prefix=#{prefix}])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %W[build])
        expect(result.stderr).to eq ""
        expect(result.stdout).to_not match /Install/
        expect(Dir.entries(prefix)).to match_array %w[. ..]

        result = run_rscons(rsconscript: "install.rb", op: %W[install])
        expect(result.stderr).to eq ""
        expect(result.stdout).to match /Install/
      end
    end
  end

  context "uninstall operation" do
    it "removes installed files but not built files" do
      test_dir "typical"

      Dir.mktmpdir do |prefix|
        result = run_rscons(rsconscript: "install.rb", op: %W[configure --prefix=#{prefix}])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %W[install])
        expect(result.stderr).to eq ""
        expect(File.exists?("#{prefix}/bin/program.exe")).to be_truthy
        expect(File.exists?("build/e.1/src/one/one.o")).to be_truthy

        result = run_rscons(rsconscript: "install.rb", op: %W[uninstall])
        expect(result.stderr).to eq ""
        expect(result.stdout).to_not match /Removing/
        expect(File.exists?("#{prefix}/bin/program.exe")).to be_falsey
        expect(File.exists?("build/e.1/src/one/one.o")).to be_truthy
        expect(Dir.entries(prefix)).to match_array %w[. ..]
      end
    end

    it "prints removed files and directories when running verbosely" do
      test_dir "typical"

      Dir.mktmpdir do |prefix|
        result = run_rscons(rsconscript: "install.rb", op: %W[configure --prefix=#{prefix}])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %W[install])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %W[uninstall -v])
        expect(result.stderr).to eq ""
        expect(result.stdout).to match %r{Removing #{prefix}/bin/program.exe}
        expect(File.exists?("#{prefix}/bin/program.exe")).to be_falsey
        expect(Dir.entries(prefix)).to match_array %w[. ..]
      end
    end

    it "removes cache entries when uninstalling" do
      test_dir "typical"

      Dir.mktmpdir do |prefix|
        result = run_rscons(rsconscript: "install.rb", op: %W[configure --prefix=#{prefix}])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %W[install])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %W[uninstall -v])
        expect(result.stderr).to eq ""
        expect(result.stdout).to match %r{Removing #{prefix}/bin/program.exe}
        expect(File.exists?("#{prefix}/bin/program.exe")).to be_falsey
        expect(Dir.entries(prefix)).to match_array %w[. ..]

        FileUtils.mkdir_p("#{prefix}/bin")
        File.open("#{prefix}/bin/program.exe", "w") {|fh| fh.write("hi")}
        result = run_rscons(rsconscript: "install.rb", op: %W[uninstall -v])
        expect(result.stderr).to eq ""
        expect(result.stdout).to_not match /Removing/
      end
    end
  end

  context "build progress" do
    it "does not include install targets in build progress when not doing an install" do
      test_dir "typical"

      result = run_rscons(rsconscript: "install.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{\[1/3\] Compiling},
        %r{\[2/3\] Compiling},
        %r{\[3/3\] Linking},
      ])
    end

    it "does include install targets in build progress when doing an install" do
      test_dir "typical"

      Dir.mktmpdir do |prefix|
        result = run_rscons(rsconscript: "install.rb", op: %W[configure --prefix=#{prefix}])
        expect(result.stderr).to eq ""

        result = run_rscons(rsconscript: "install.rb", op: %w[install])
        expect(result.stderr).to eq ""
        verify_lines(lines(result.stdout), [
          %r{\[1/9\] Compiling},
          %r{\[2/9\] Compiling},
          %r{\[\d/9\] Install},
        ])
      end
    end

    it "includes build steps from all environments when showing build progress" do
      test_dir "typical"

      result = run_rscons(rsconscript: "multiple_environments.rb")
      expect(result.stderr).to eq ""
      verify_lines(lines(result.stdout), [
        %r{\[1/6\] Compiling},
        %r{\[2/6\] Compiling},
        %r{\[3/6\] Linking},
        %r{\[4/6\] Compiling},
        %r{\[5/6\] Compiling},
        %r{\[6/6\] Linking},
      ])
    end
  end

end
