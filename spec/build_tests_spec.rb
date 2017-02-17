require 'fileutils'

class Dir
  class << self
    alias_method :orig_bracket, :[]
  end
  def self.[](*args)
    orig_bracket(*args).sort
  end
end

describe Rscons do

  BUILD_TEST_RUN_DIR = "build_test_run"

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
    rm_rf(BUILD_TEST_RUN_DIR)
    @owd = Dir.pwd
  end

  before(:each) do
    @saved_stdout = $stdout
    $stdout = StringIO.new
    @saved_stderr = $stderr
    $stderr = StringIO.new
  end

  after(:each) do
    $stdout = @saved_stdout
    $stderr = @saved_stderr
    Dir.chdir(@owd)
    rm_rf(BUILD_TEST_RUN_DIR)
  end

  def test_dir(build_test_directory)
    FileUtils.cp_r("build_tests/#{build_test_directory}", BUILD_TEST_RUN_DIR)
    Dir.chdir(BUILD_TEST_RUN_DIR)
    @saved_stderr.reopen(".stderr")
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

  def lines
    rv = ($stdout.string + $stderr.string).lines.map(&:rstrip)
    $stdout.string = ""
    $stderr.string = ""
    rv
  end

  ###########################################################################
  # Tests
  ###########################################################################

  it 'builds a C program with one source file' do
    test_dir('simple')
    Rscons::Environment.new do |env|
      env.Program('simple', Dir['*.c'])
    end
    expect(File.exists?('simple.o')).to be_truthy
    expect(`./simple`).to eq "This is a simple C program\n"
  end

  it 'prints commands as they are executed' do
    test_dir('simple')
    env = Rscons::Environment.new(echo: :command) do |env|
      env["LD"] = "gcc"
      env.Program('simple', Dir['*.c'])
    end
    expect(lines).to eq [
      'gcc -c -o simple.o -MMD -MF simple.mf simple.c',
      "gcc -o simple#{env["PROGSUFFIX"]} simple.o",
    ]
  end

  it 'prints short representations of the commands being executed' do
    test_dir('header')
    env = Rscons::Environment.new do |env|
      env.Program('header', Dir['*.c'])
    end
    expect(lines).to eq [
      'CC header.o',
      "LD header#{env["PROGSUFFIX"]}",
    ]
  end

  it 'builds a C program with one source file and one header file' do
    test_dir('header')
    Rscons::Environment.new do |env|
      env.Program('header', Dir['*.c'])
    end
    expect(File.exists?('header.o')).to be_truthy
    expect(`./header`).to eq "The value is 2\n"
  end

  it 'rebuilds a C module when a header it depends on changes' do
    test_dir('header')
    make_env = lambda do
      Rscons::Environment.new do |env|
        env.Program('header', Dir['*.c'])
      end
    end
    make_env[]
    expect(`./header`).to eq "The value is 2\n"
    file_sub('header.h') {|line| line.sub(/2/, '5')}
    make_env[]
    expect(`./header`).to eq "The value is 5\n"
  end

  it 'does not rebuild a C module when its dependencies have not changed' do
    test_dir('header')
    make_env = lambda do
      Rscons::Environment.new do |env|
        env.Program('header', Dir['*.c'])
      end
    end
    env = make_env[]
    expect(`./header`).to eq "The value is 2\n"
    expect(lines).to eq [
      'CC header.o',
      "LD header#{env["PROGSUFFIX"]}",
    ]
    make_env[]
    expect(lines).to eq []
  end

  it "does not rebuild a C module when only the file's timestamp has changed" do
    test_dir('header')
    make_env = lambda do
      Rscons::Environment.new do |env|
        env.Program('header', Dir['*.c'])
      end
    end
    env = make_env[]
    expect(`./header`).to eq "The value is 2\n"
    expect(lines).to eq [
      'CC header.o',
      "LD header#{env["PROGSUFFIX"]}",
    ]
    sleep 0.05
    file_sub('header.c') {|line| line}
    make_env[]
    expect(lines).to eq []
  end

  it 're-links a program when the link flags have changed' do
    test_dir('simple')
    env = Rscons::Environment.new(echo: :command) do |env|
      env.Program('simple', Dir['*.c'])
    end
    expect(lines).to eq [
      'gcc -c -o simple.o -MMD -MF simple.mf simple.c',
      "gcc -o simple#{env["PROGSUFFIX"]} simple.o",
    ]
    e2 = Rscons::Environment.new(echo: :command) do |env|
      env["LIBPATH"] += ["libdir"]
      env.Program('simple', Dir['*.c'])
    end
    expect(lines).to eq ["gcc -o simple#{env["PROGSUFFIX"]} simple.o -Llibdir"]
  end

  it 'builds object files in a different build directory' do
    test_dir('build_dir')
    Rscons::Environment.new do |env|
      env.append('CPPPATH' => Dir['src/**/*/'])
      env.build_dir(%r{^src/([^/]+)/}, 'build_\\1/')
      env.Program('build_dir', Dir['src/**/*.c'])
    end
    expect(`./build_dir`).to eq "Hello from two()\n"
    expect(File.exists?('build_one/one.o')).to be_truthy
    expect(File.exists?('build_two/two.o')).to be_truthy
  end

  it "supports trailing slashes at the end of build_dir sources and destinations" do
    test_dir("build_dir")
    Rscons::Environment.new do |env|
      env.append("CPPPATH" => Dir["src/**/*/"])
      env.build_dir("src/one/", "build_one/")
      env.build_dir("src/two", "build_two")
      env.Program("build_dir", Dir["src/**/*.c"])
    end
    expect(`./build_dir`).to eq "Hello from two()\n"
    expect(File.exists?("build_one/one.o")).to be_truthy
    expect(File.exists?("build_two/two.o")).to be_truthy
  end

  it 'uses build directories before build root' do
    test_dir('build_dir')
    env = Rscons::Environment.new do |env|
      env.append('CPPPATH' => Dir['src/**/*/'])
      env.build_dir("src", "build")
      env.build_root = "build_root"
      env.Program('build_dir', Dir['src/**/*.c'])
    end
    expect(lines).to eq ["CC build/one/one.o", "CC build/two/two.o", "LD build_dir#{env["PROGSUFFIX"]}"]
  end

  it 'uses build_root if no build directories match' do
    test_dir('build_dir')
    Rscons::Environment.new do |env|
      env.append('CPPPATH' => Dir['src/**/*/'])
      env.build_dir("src2", "build")
      env.build_root = "build_root"
      env.Program('build_dir.exe', Dir['src/**/*.c'])
    end
    expect(lines).to eq ["CC build_root/src/one/one.o", "CC build_root/src/two/two.o", "LD build_dir.exe"]
  end

  it "expands target and source paths starting with ^/ to be relative to the build root" do
    test_dir('build_dir')
    env = Rscons::Environment.new(echo: :command) do |env|
      env.append('CPPPATH' => Dir['src/**/*/'])
      env.build_root = "build_root"
      FileUtils.mkdir_p(env.build_root)
      FileUtils.mv("src/one/one.c", "build_root")
      env.Object("^/one.o", "^/one.c")
      env.Program('build_dir', Dir['src/**/*.c'] + ["^/one.o"])
    end
    expect(lines).to eq [
      %q{gcc -c -o build_root/one.o -MMD -MF build_root/one.mf -Isrc/one/ -Isrc/two/ build_root/one.c},
      %q{gcc -c -o build_root/src/two/two.o -MMD -MF build_root/src/two/two.mf -Isrc/one/ -Isrc/two/ src/two/two.c},
      %Q{gcc -o build_dir#{env["PROGSUFFIX"]} build_root/src/two/two.o build_root/one.o},
    ]
  end

  it 'supports simple builders' do
    test_dir('json_to_yaml')
    Rscons::Environment.new do |env|
      require 'json'
      require 'yaml'
      env.add_builder(:JsonToYaml) do |target, sources, cache, env, vars|
        unless cache.up_to_date?(target, :JsonToYaml, sources, env)
          cache.mkdir_p(File.dirname(target))
          File.open(target, 'w') do |f|
            f.write(YAML.dump(JSON.load(IO.read(sources.first))))
          end
          cache.register_build(target, :JsonToYaml, sources, env)
        end
        target
      end
      env.JsonToYaml('foo.yml','foo.json')
    end
    expect(File.exists?('foo.yml')).to be_truthy
    expect(IO.read('foo.yml')).to eq("---\nkey: value\n")
  end

  it 'cleans built files' do
    test_dir('build_dir')
    Rscons::Environment.new do |env|
      env.append('CPPPATH' => Dir['src/**/*/'])
      env.build_dir(%r{^src/([^/]+)/}, 'build_\\1/')
      env.Program('build_dir', Dir['src/**/*.c'])
    end
    expect(`./build_dir`).to eq "Hello from two()\n"
    expect(File.exists?('build_one/one.o')).to be_truthy
    expect(File.exists?('build_two/two.o')).to be_truthy
    Rscons.clean
    expect(File.exists?('build_one/one.o')).to be_falsey
    expect(File.exists?('build_two/two.o')).to be_falsey
    expect(File.exists?('build_one')).to be_falsey
    expect(File.exists?('build_two')).to be_falsey
    expect(File.exists?('src/one/one.c')).to be_truthy
  end

  it 'does not clean created directories if other non-rscons-generated files reside there' do
    test_dir('build_dir')
    Rscons::Environment.new do |env|
      env.append('CPPPATH' => Dir['src/**/*/'])
      env.build_dir(%r{^src/([^/]+)/}, 'build_\\1/')
      env.Program('build_dir', Dir['src/**/*.c'])
    end
    expect(`./build_dir`).to eq "Hello from two()\n"
    expect(File.exists?('build_one/one.o')).to be_truthy
    expect(File.exists?('build_two/two.o')).to be_truthy
    File.open('build_two/tmp', 'w') { |fh| fh.puts "dum" }
    Rscons.clean
    expect(File.exists?('build_one/one.o')).to be_falsey
    expect(File.exists?('build_two/two.o')).to be_falsey
    expect(File.exists?('build_one')).to be_falsey
    expect(File.exists?('build_two')).to be_truthy
    expect(File.exists?('src/one/one.c')).to be_truthy
  end

  it 'allows Ruby classes as custom builders to be used to construct files' do
    test_dir('custom_builder')
    class MySource < Rscons::Builder
      def run(target, sources, cache, env, vars)
        File.open(target, 'w') do |fh|
          fh.puts <<EOF
    #define THE_VALUE 5678
EOF
        end
        target
      end
    end

    env = Rscons::Environment.new do |env|
      env.add_builder(MySource.new)
      env.MySource('inc.h', [])
      env.Program('program', Dir['*.c'])
    end

    expect(lines).to eq ["CC program.o", "LD program#{env["PROGSUFFIX"]}"]
    expect(File.exists?('inc.h')).to be_truthy
    expect(`./program`).to eq "The value is 5678\n"
  end

  it 'supports custom builders with multiple targets' do
    test_dir('custom_builder')
    class CHGen < Rscons::Builder
      def run(target, sources, cache, env, vars)
        c_fname = target
        h_fname = target.sub(/\.c$/, ".h")
        unless cache.up_to_date?([c_fname, h_fname], "", sources, env)
          puts "CHGen #{c_fname}"
          File.open(c_fname, "w") {|fh| fh.puts "int THE_VALUE = 42;"}
          File.open(h_fname, "w") {|fh| fh.puts "extern int THE_VALUE;"}
          cache.register_build([c_fname, h_fname], "", sources, env)
        end
        target
      end
    end

    make_env = lambda do
      Rscons::Environment.new do |env|
        env.add_builder(CHGen.new)
        env.CHGen("inc.c", ["program.c"])
        env.Program("program", %w[program.c inc.c])
      end
    end
    env = make_env[]

    expect(lines).to eq ["CHGen inc.c", "CC program.o", "CC inc.o", "LD program#{env["PROGSUFFIX"]}"]
    expect(File.exists?("inc.c")).to be_truthy
    expect(File.exists?("inc.h")).to be_truthy
    expect(`./program`).to eq "The value is 42\n"

    File.open("inc.c", "w") {|fh| fh.puts "int THE_VALUE = 33;"}
    make_env[]
    expect(lines).to eq ["CHGen inc.c"]
    expect(`./program`).to eq "The value is 42\n"
  end

  it 'allows cloning Environment objects' do
    test_dir('clone_env')

    debug = Rscons::Environment.new(echo: :command) do |env|
      env.build_dir('src', 'debug')
      env['CFLAGS'] = '-O2'
      env['CPPFLAGS'] = '-DSTRING="Debug Version"'
      env.Program('program-debug', Dir['src/*.c'])
    end

    release = debug.clone do |env|
      env["CPPFLAGS"] = '-DSTRING="Release Version"'
      env.build_dir('src', 'release')
      env.Program('program-release', Dir['src/*.c'])
    end

    expect(lines).to eq [
      %q{gcc -c -o debug/program.o -MMD -MF debug/program.mf '-DSTRING="Debug Version"' -O2 src/program.c},
      %Q{gcc -o program-debug#{debug["PROGSUFFIX"]} debug/program.o},
      %q{gcc -c -o release/program.o -MMD -MF release/program.mf '-DSTRING="Release Version"' -O2 src/program.c},
      %Q{gcc -o program-release#{debug["PROGSUFFIX"]} release/program.o},
    ]
  end

  it 'allows cloning all attributes of an Environment object' do
    test_dir('clone_env')

    built_targets = []
    env1 = Rscons::Environment.new(echo: :command) do |env|
      env.build_dir('src', 'build')
      env['CFLAGS'] = '-O2'
      env.add_build_hook do |build_op|
        build_op[:vars]['CPPFLAGS'] = '-DSTRING="Hello"'
      end
      env.add_post_build_hook do |build_op|
        built_targets << build_op[:target]
      end
      env.Program('program', Dir['src/*.c'])
    end

    env2 = env1.clone(clone: :all) do |env|
      env.Program('program2', Dir['src/*.c'])
    end

    expect(lines).to eq [
      %q{gcc -c -o build/program.o -MMD -MF build/program.mf -DSTRING="Hello" -O2 src/program.c},
      %Q{gcc -o program#{env1["PROGSUFFIX"]} build/program.o},
      %Q{gcc -o program2#{env2["PROGSUFFIX"]} build/program.o},
    ]
    expect(built_targets).to eq([
      "build/program.o",
      "program#{env1['PROGSUFFIX']}",
      "build/program.o",
      "program2#{env1['PROGSUFFIX']}",
    ])
  end

  it 'builds a C++ program with one source file' do
    test_dir('simple_cc')
    Rscons::Environment.new do |env|
      env.Program('simple', Dir['*.cc'])
    end
    expect(File.exists?('simple.o')).to be_truthy
    expect(`./simple`).to eq "This is a simple C++ program\n"
  end

  it 'allows overriding construction variables for individual builder calls' do
    test_dir('two_sources')
    env = Rscons::Environment.new(echo: :command) do |env|
      env.Object("one.o", "one.c", 'CPPFLAGS' => ['-DONE'])
      env.Program('two_sources', ['one.o', 'two.c'])
    end
    expect(lines).to eq [
      'gcc -c -o one.o -MMD -MF one.mf -DONE one.c',
      'gcc -c -o two.o -MMD -MF two.mf two.c',
      "gcc -o two_sources#{env["PROGSUFFIX"]} one.o two.o",
    ]
    expect(File.exists?("two_sources#{env["PROGSUFFIX"]}")).to be_truthy
    expect(`./two_sources`).to eq "This is a C program with two sources.\n"
  end

  it 'builds a static library archive' do
    test_dir('library')
    env = Rscons::Environment.new(echo: :command) do |env|
      env.Program('library', ['lib.a', 'three.c'])
      env.Library("lib.a", ['one.c', 'two.c'], 'CPPFLAGS' => ['-Dmake_lib'])
    end
    expect(lines).to eq [
      'gcc -c -o one.o -MMD -MF one.mf -Dmake_lib one.c',
      'gcc -c -o two.o -MMD -MF two.mf -Dmake_lib two.c',
      'ar rcs lib.a one.o two.o',
      'gcc -c -o three.o -MMD -MF three.mf three.c',
      "gcc -o library#{env["PROGSUFFIX"]} lib.a three.o",
    ]
    expect(File.exists?("library#{env["PROGSUFFIX"]}")).to be_truthy
    expect(`ar t lib.a`).to eq "one.o\ntwo.o\n"
  end

  it 'supports build hooks to override construction variables' do
    test_dir("build_dir")
    env = Rscons::Environment.new(echo: :command) do |env|
      env.append('CPPPATH' => Dir['src/**/*/'])
      env.build_dir(%r{^src/([^/]+)/}, 'build_\\1/')
      env.add_build_hook do |build_op|
        if build_op[:target] =~ %r{build_one/.*\.o}
          build_op[:vars]["CFLAGS"] << "-O1"
        elsif build_op[:target] =~ %r{build_two/.*\.o}
          build_op[:vars]["CFLAGS"] << "-O2"
        end
      end
      env.Program('build_hook.exe', Dir['src/**/*.c'])
    end
    expect(`./build_hook.exe`).to eq "Hello from two()\n"
    expect(lines).to match_array [
      'gcc -c -o build_one/one.o -MMD -MF build_one/one.mf -Isrc/one/ -Isrc/two/ -O1 src/one/one.c',
      'gcc -c -o build_two/two.o -MMD -MF build_two/two.mf -Isrc/one/ -Isrc/two/ -O2 src/two/two.c',
      'gcc -o build_hook.exe build_one/one.o build_two/two.o',
    ]
  end

  it 'rebuilds when user-specified dependencies change' do
    test_dir('simple')
    env = Rscons::Environment.new do |env|
      env.Program('simple.exe', Dir['*.c']).depends("file.ld")
      File.open("file.ld", "w") do |fh|
        fh.puts("foo")
      end
    end
    expect(lines).to eq ["CC simple.o", "LD simple.exe"]
    expect(File.exists?('simple.o')).to be_truthy
    expect(`./simple.exe`).to eq "This is a simple C program\n"
    e2 = Rscons::Environment.new do |env|
      program = env.Program('simple.exe', Dir['*.c'])
      env.depends(program, "file.ld")
      File.open("file.ld", "w") do |fh|
        fh.puts("bar")
      end
    end
    expect(lines).to eq ["LD simple.exe"]
    e3 = Rscons::Environment.new do |env|
      env.Program('simple.exe', Dir['*.c'])
      File.unlink("file.ld")
    end
    expect(lines).to eq ["LD simple.exe"]
    Rscons::Environment.new do |env|
      env.Program('simple.exe', Dir['*.c'])
    end
    expect(lines).to eq []
  end

  unless ENV["omit_gdc_tests"]
    it "supports building D sources" do
      test_dir("d")
      Rscons::Environment.new(echo: :command) do |env|
        env.Program("hello-d.exe", Dir["*.d"])
      end
      expect(lines).to eq [
        "gdc -c -o main.o main.d",
        "gdc -o hello-d.exe main.o",
      ]
      expect(`./hello-d.exe`.rstrip).to eq "Hello from D!"
    end
  end

  it "supports disassembling object files" do
    test_dir("simple")
    Rscons::Environment.new do |env|
      env.Object("simple.o", "simple.c")
      env.Disassemble("simple.txt", "simple.o")
    end
    expect(File.exists?("simple.txt")).to be_truthy
    expect(File.read("simple.txt")).to match /Disassembly of section .text:/
  end

  it "supports preprocessing C sources" do
    test_dir("simple")
    Rscons::Environment.new do |env|
      env.Preprocess("simplepp.c", "simple.c")
      env.Program("simple", "simplepp.c")
    end
    expect(File.read("simplepp.c")).to match /# \d+ "simple.c"/
    expect(`./simple`).to eq "This is a simple C program\n"
  end

  it "supports preprocessing C++ sources" do
    test_dir("simple_cc")
    Rscons::Environment.new do |env|
      env.Preprocess("simplepp.cc", "simple.cc")
      env.Program("simple", "simplepp.cc")
    end
    expect(File.read("simplepp.cc")).to match /# \d+ "simple.cc"/
    expect(`./simple`).to eq "This is a simple C++ program\n"
  end

  it "supports invoking builders with no sources and a build_root defined" do
    class TestBuilder < Rscons::Builder
      def run(target, sources, cache, env, vars)
        target
      end
    end
    test_dir("simple")
    Rscons::Environment.new do |env|
      env.build_root = "build"
      env.add_builder(TestBuilder.new)
      env.TestBuilder("file")
    end
  end

  it "expands construction variables in builder target and sources before invoking the builder" do
    test_dir('custom_builder')
    class MySource < Rscons::Builder
      def run(target, sources, cache, env, vars)
        File.open(target, 'w') do |fh|
          fh.puts <<EOF
    #define THE_VALUE 678
EOF
        end
        target
      end
    end

    env = Rscons::Environment.new do |env|
      env["hdr"] = "inc.h"
      env["src"] = "program.c"
      env.add_builder(MySource.new)
      env.MySource('${hdr}')
      env.Program('program', "${src}")
    end

    expect(lines).to eq ["CC program.o", "LD program#{env["PROGSUFFIX"]}"]
    expect(File.exists?('inc.h')).to be_truthy
    expect(`./program`).to eq "The value is 678\n"
  end

  it "supports lambdas as construction variable values" do
    env = Rscons::Environment.new do |env|
      env["prefix"] = "-H"
      env["suffix"] = "xyz"
      env[:cfg] = {val: 44}
      env["computed"] = lambda do |args|
        "#{args[:env]['prefix']}#{args[:env][:cfg][:val]}#{args[:env]['suffix']}"
      end
      env["lambda_recurse"] = lambda do |args|
        "${prefix}ello"
      end
    end
    e2 = env.clone
    e2[:cfg][:val] = 38
    expect(env.expand_varref("${computed}")).to eq("-H44xyz")
    expect(e2.expand_varref("${computed}")).to eq("-H38xyz")
    expect(env.expand_varref("${lambda_recurse}")).to eq("-Hello")
  end

  it "supports registering build targets from within a build hook" do
    test_dir("simple")
    Rscons::Environment.new do |env|
      env.Program("simple", Dir["*.c"])
      env.add_build_hook do |build_op|
        if build_op[:target].end_with?(".o")
          env.Disassemble("#{build_op[:target]}.txt", build_op[:target])
        end
      end
    end
    expect(File.exists?("simple.o")).to be_truthy
    expect(File.exists?("simple.o.txt")).to be_truthy
    expect(`./simple`).to eq "This is a simple C program\n"
  end

  it "supports post-build hooks" do
    test_dir("simple")
    built_targets = []
    env = Rscons::Environment.new do |env|
      env.Program("simple", Dir["*.c"])
      env.add_post_build_hook do |build_op|
        built_targets << build_op[:target]
        expect(File.exists?(build_op[:target])).to be_truthy
      end
    end
    expect(File.exists?("simple.o")).to be_truthy
    expect(`./simple`).to eq "This is a simple C program\n"
    expect(built_targets).to eq ["simple.o", "simple#{env["PROGSUFFIX"]}"]
  end

  it "supports multiple values for CXXSUFFIX" do
    test_dir("simple_cc")
    File.open("other.cccc", "w") {|fh| fh.puts}
    Rscons::Environment.new do |env|
      env["CXXSUFFIX"] = %w[.cccc .cc]
      env["CXXFLAGS"] += %w[-x c++]
      env.Program("simple", Dir["*.cc"] + ["other.cccc"])
    end
    expect(File.exists?("simple.o")).to be_truthy
    expect(File.exists?("other.o")).to be_truthy
    expect(`./simple`).to eq "This is a simple C++ program\n"
  end

  it "supports multiple values for CSUFFIX" do
    test_dir("build_dir")
    FileUtils.mv("src/one/one.c", "src/one/one.yargh")
    Rscons::Environment.new do |env|
      env["CSUFFIX"] = %w[.yargh .c]
      env["CFLAGS"] += %w[-x c]
      env["CPPPATH"] += Dir["src/**/"]
      env.Program("build_dir", Dir["src/**/*.{c,yargh}"])
    end
    expect(File.exists?("src/one/one.o")).to be_truthy
    expect(File.exists?("src/two/two.o")).to be_truthy
    expect(`./build_dir`).to eq "Hello from two()\n"
  end

  it "supports multiple values for OBJSUFFIX" do
    test_dir("two_sources")
    env = Rscons::Environment.new() do |env|
      env["OBJSUFFIX"] = %w[.oooo .ooo]
      env.Object("one.oooo", "one.c", "CPPFLAGS" => ["-DONE"])
      env.Object("two.ooo", "two.c")
      env.Program("two_sources", %w[one.oooo two.ooo])
    end
    expect(File.exists?("two_sources#{env["PROGSUFFIX"]}")).to be_truthy
    expect(`./two_sources`).to eq "This is a C program with two sources.\n"
  end

  it "supports multiple values for LIBSUFFIX" do
    test_dir("two_sources")
    env = Rscons::Environment.new() do |env|
      env["LIBSUFFIX"] = %w[.aaaa .aaa]
      env.Library("one.aaaa", "one.c", "CPPFLAGS" => ["-DONE"])
      env.Library("two.aaa", "two.c")
      env.Program("two_sources", %w[one.aaaa two.aaa])
    end
    expect(File.exists?("two_sources#{env["PROGSUFFIX"]}")).to be_truthy
    expect(`./two_sources`).to eq "This is a C program with two sources.\n"
  end

  it "supports multiple values for ASSUFFIX" do
    test_dir("two_sources")
    env = Rscons::Environment.new() do |env|
      env["ASSUFFIX"] = %w[.ssss .sss]
      env["CFLAGS"] += %w[-S]
      env.Object("one.ssss", "one.c", "CPPFLAGS" => ["-DONE"])
      env.Object("two.sss", "two.c")
      env.Program("two_sources", %w[one.ssss two.sss], "ASFLAGS" => env["ASFLAGS"] + %w[-x assembler])
    end
    expect(lines).to eq([
      "CC one.ssss",
      "CC two.sss",
      "AS one.o",
      "AS two.o",
      "LD two_sources#{env["PROGSUFFIX"]}",
    ])
    expect(File.exists?("two_sources#{env["PROGSUFFIX"]}")).to be_truthy
    expect(`./two_sources`).to eq "This is a C program with two sources.\n"
  end

  it "supports dumping an Environment's construction variables" do
    test_dir("simple")
    env = Rscons::Environment.new do |env|
      env["CFLAGS"] += %w[-O2 -fomit-frame-pointer]
      env[:foo] = :bar
    end
    env.dump
    result = lines
    expect(result.include?(%{:foo => :bar})).to be_truthy
    expect(result.include?(%{CFLAGS => ["-O2", "-fomit-frame-pointer"]})).to be_truthy
    expect(result.include?(%{CPPPATH => []})).to be_truthy
  end

  it "considers deep dependencies when deciding whether to rerun Preprocess builder" do
    test_dir("preprocess")
    env = Rscons::Environment.new do |env|
      env.Preprocess("pp", "foo.h")
    end
    expect(File.read("pp")).to match(%r{xyz42abc}m)
    expect(lines).to eq(["Preprocess pp"])
    env.Preprocess("pp", "foo.h")
    env.process
    expect(lines).to eq([])
    File.open("bar.h", "w") do |fh|
      fh.puts "#define BAR abc88xyz"
    end
    $ttt = true
    env.Preprocess("pp", "foo.h")
    env.process
    expect(lines).to eq(["Preprocess pp"])
    expect(File.read("pp")).to match(%r{abc88xyz}m)
  end

  it "allows construction variable references which expand to arrays in sources of a build target" do
    test_dir("simple")
    Rscons::Environment.new do |env|
      env["sources"] = Dir["*.c"]
      env.Program("simple", "${sources}")
    end
    expect(File.exists?("simple.o")).to be_truthy
    expect(`./simple`).to eq "This is a simple C program\n"
  end

  it "supports registering multiple build targets with the same target path" do
    test_dir("build_dir")
    Rscons::Environment.new do |env|
      env["CPPPATH"] << "src/two"
      env.Object("one.o", "src/one/one.c")
      env.Object("one.o", "src/two/two.c")
    end
    expect(File.exists?("one.o")).to be_truthy
    expect(lines).to eq([
      "CC one.o",
      "CC one.o",
    ])
  end

  it "expands target and source paths when builders are registered in build hooks" do
    test_dir("build_dir")
    Rscons::Environment.new do |env|
      env["CPPPATH"] << "src/two"
      env.Object("one.o", "src/one/one.c")
      env.add_post_build_hook do |build_op|
        if build_op[:target] == "one.o"
          env["MODULE"] = "two"
          env.Object("${MODULE}.o", "src/${MODULE}/${MODULE}.c")
        end
      end
    end
    expect(File.exists?("one.o")).to be_truthy
    expect(File.exists?("two.o")).to be_truthy
    expect(lines).to eq([
      "CC one.o",
      "CC two.o",
    ])
  end

  it "does not re-run previously successful builders if one fails" do
    test_dir('simple')
    File.open("two.c", "w") do |fh|
      fh.puts("FOO")
    end
    expect do
      Rscons::Environment.new do |env|
        env.Program("simple", %w[simple.c two.c])
      end
    end.to raise_error /Failed to build simple/
    result = lines
    expect(result.size).to be > 2
    expect(result[0, 2]).to eq [
      "CC simple.o",
      "CC two.o",
    ]
    expect(File.exists?("simple.o")).to be_truthy
    expect(File.exists?("two.o")).to be_falsey
    expect(File.exists?("two_sources#{Rscons::Environment.new["PROGSUFFIX"]}")).to be_falsey

    Rscons::Cache.reset!

    File.open("two.c", "w") {|fh|}
    Rscons::Environment.new do |env|
      env.Program("simple", %w[simple.c two.c])
    end
    expect(lines).to eq [
      "CC two.o",
      "LD simple",
    ]
  end

  context "Directory builder" do
    it "creates the requested directory" do
      test_dir("simple")
      Rscons::Environment.new do |env|
        env.Directory("teh_dir")
      end
      expect(File.directory?("teh_dir")).to be_truthy
      expect(lines).to eq(["Directory teh_dir"])
    end

    it "succeeds when the requested directory already exists" do
      test_dir("simple")
      FileUtils.mkdir("teh_dir")
      Rscons::Environment.new do |env|
        env.Directory("teh_dir")
      end
      expect(File.directory?("teh_dir")).to be_truthy
      expect(lines).to eq([])
    end

    it "fails when the target path is a file" do
      test_dir("simple")
      FileUtils.touch("teh_dir")
      expect do
        Rscons::Environment.new do |env|
          env.Directory("teh_dir")
        end
      end.to raise_error /Failed to build teh_dir/
      expect(lines).to eq([
        "Error: `teh_dir' already exists and is not a directory",
      ])
    end
  end

  context "Install buildler" do
    let(:base_env) do
      test_dir("build_dir")
      Rscons::Environment.new do |env|
        env["CPPPATH"] = Dir["src/**/"]
        env["sources"] = Dir["src/**/*.c"]
        env.Program("simple.exe", "${sources}")
      end
    end

    it "copies a file to the target file name" do
      env = base_env.clone do |env|
        lines
        env.Install("inst.exe", "simple.exe")
      end
      expect(lines).to eq(["Install inst.exe"])
      env.Install("inst.exe", "simple.exe")
      env.process
      expect(lines).to eq([])
      expect(File.exists?("inst.exe")).to be_truthy
      expect(File.read("inst.exe", mode: "rb")).to eq(File.read("simple.exe", mode: "rb"))
      FileUtils.rm("inst.exe")
      env.Install("inst.exe", "simple.exe")
      env.process
      expect(lines).to eq(["Install inst.exe"])
    end

    it "operates the same as a Copy builder" do
      env = base_env.clone do |env|
        lines
        env.Copy("inst.exe", "simple.exe")
      end
      expect(lines).to eq(["Copy inst.exe"])
      env.Copy("inst.exe", "simple.exe")
      env.process
      expect(lines).to eq([])
      expect(File.exists?("inst.exe")).to be_truthy
      expect(File.read("inst.exe", mode: "rb")).to eq(File.read("simple.exe", mode: "rb"))
      FileUtils.rm("inst.exe")
      env.Copy("inst.exe", "simple.exe")
      env.process
      expect(lines).to eq(["Copy inst.exe"])
    end

    it "copies a file to the target directory name" do
      env = base_env.clone do |env|
        lines
        env.Directory("inst")
        env.Install("inst", "simple.exe")
      end
      expect(lines).to eq([
        "Directory inst",
        "Install inst",
      ])
      env.Install("inst", "simple.exe")
      env.process
      expect(lines).to eq([])
      expect(File.exists?("inst/simple.exe")).to be_truthy
      expect(File.read("inst/simple.exe", mode: "rb")).to eq(File.read("simple.exe", mode: "rb"))
    end

    it "copies a directory to the non-existent target directory name" do
      env = base_env.clone do |env|
        lines
        env.Install("dist/src", "src")
      end
      expect(lines).to eq(["Install dist/src"])
      env.Install("dist/src", "src")
      env.process
      expect(lines).to eq([])
      %w[src/one/one.c src/two/two.c src/two/two.h].each do |f|
        expect(File.exists?("dist/#{f}")).to be_truthy
        expect(File.read("dist/#{f}", mode: "rb")).to eq(File.read(f, mode: "rb"))
      end
    end

    it "copies a directory to the existent target directory name" do
      env = base_env.clone do |env|
        lines
        env.Directory("dist/src")
        env.Install("dist/src", "src")
      end
      expect(lines).to eq([
        "Directory dist/src",
        "Install dist/src",
      ])
      env.Install("dist/src", "src")
      env.process
      expect(lines).to eq([])
      %w[src/one/one.c src/two/two.c src/two/two.h].each do |f|
        expect(File.exists?("dist/#{f}")).to be_truthy
        expect(File.read("dist/#{f}", mode: "rb")).to eq(File.read(f, mode: "rb"))
      end
      FileUtils.rm("dist/src/two/two.c")
      env.Install("dist/src", "src")
      env.process
      expect(lines).to eq(["Install dist/src"])
    end
  end

  context "phony targets" do
    [false, true].each do |with_build_root|
      it "allows specifying a Symbol as a target name and reruns the builder if the sources or command have changed" do
        test_dir("simple")
        env = Rscons::Environment.new do |env|
          env.build_root = "bld" if with_build_root
          env.add_builder(:Checker) do |target, sources, cache, env, vars|
            unless cache.up_to_date?(target, :Checker, sources, env)
              puts "Checker #{sources.first}" if env.echo != :off
              cache.register_build(target, :Checker, sources, env)
            end
            target
          end
          env.Program("simple.exe", "simple.c")
          env.Checker(:checker, "simple.exe")
        end
        expect(lines).to eq(["CC #{with_build_root ? 'bld/' : ''}simple.o", "LD simple.exe", "Checker simple.exe"])

        env.clone do |env|
          env.Checker(:checker, "simple.exe")
        end
        expect(lines).to eq([])

        File.open("simple.exe", "w") do |fh|
          fh.puts "Changed simple.exe"
        end
        env.clone do |env|
          env.Checker(:checker, "simple.exe")
        end
        expect(lines).to eq(["Checker simple.exe"])
      end
    end
  end

  context "Environment#clear_targets" do
    it "clears registered targets" do
      test_dir('header')
      env = Rscons::Environment.new do |env|
        env.Program('header', Dir['*.c'])
        env.clear_targets
      end
      expect(lines).to eq []
    end
  end

end
