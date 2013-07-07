require 'fileutils'

describe Rscons do
  before(:all) do
    FileUtils.rm_rf('build_tests_run')
    @owd = Dir.pwd
  end

  after(:each) do
    Dir.chdir(@owd)
    FileUtils.rm_rf('build_tests_run')
  end

  def build_testdir
    if File.exists?("build.rb")
      system("ruby -I #{@owd}/lib -r rscons build.rb > build.out")
    end
  end

  def test_dir(build_test_directory)
    FileUtils.cp_r("build_tests/#{build_test_directory}", 'build_tests_run')
    Dir.chdir("build_tests_run")
    build_testdir
  end

  def file_sub(fname)
    contents = File.read(fname)
    replaced = ''
    contents.each_line do |line|
      replaced += yield(line)
    end
    File.open(fname, 'w') do |fh|
      fh.write(replaced)
    end
  end

  ###########################################################################
  # Tests
  ###########################################################################

  it 'builds a C program with one source file' do
    test_dir('simple')
    File.exists?('simple.o').should be_true
    `./simple`.should == "This is a simple C program\n"
  end

  it 'prints commands as they are executed' do
    test_dir('simple')
    File.read('build.out').should == <<EOF
gcc -c -o simple.o -MMD -MF simple.mf simple.c
gcc -o simple simple.o
EOF
  end

  it 'builds a C program with one source file and one header file' do
    test_dir('header')
    File.exists?('header.o').should be_true
    `./header`.should == "The value is 2\n"
  end

  it 'rebuilds a C module when a header it depends on changes' do
    test_dir('header')
    `./header`.should == "The value is 2\n"
    file_sub('header.h') {|line| line.sub(/2/, '5')}
    build_testdir
    `./header`.should == "The value is 5\n"
  end
end
