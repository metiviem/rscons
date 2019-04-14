require "bundler"
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  raise LoadError.new("Unable to setup Bundler; you might need to `bundle install`: #{e.message}")
end

require "rspec/core/rake_task"
require "yard"
require "rake/clean"
require "fileutils"

CLEAN.include %w[build_test_run .yardoc doc coverage test]
CLOBBER.include %w[dist pkg]

task :build_dist do
  sh "ruby rb/build_dist.rb"
end

RSpec::Core::RakeTask.new(:spec, :example_string) do |task, args|
  if args.example_string
    ENV["partial_specs"] = "1"
    task.rspec_opts = %W[-e "#{args.example_string}" -f documentation]
  end
end
task :spec => :build_dist

# dspec task is useful to test the distributable release script, but is not
# useful for coverage information.
desc "Dist Specs"
task :dspec, [:example_string] => :build_dist do |task, args|
  FileUtils.mkdir_p("test")
  FileUtils.cp("dist/rscons", "test/rscons.rb")
  ENV["dist_specs"] = "1"
  Rake::Task["spec"].invoke(args.example_string)
  ENV.delete("dist_specs")
  FileUtils.rm_f(Dir.glob(".rscons-*"))
end

YARD::Rake::YardocTask.new do |yard|
  yard.files = ['lib/**/*.rb']
end

task :default => :spec
