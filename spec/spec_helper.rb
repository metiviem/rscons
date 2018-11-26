require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/.bundle/"
  if ENV["partial_specs"]
    command_name "RSpec-partial"
  else
    command_name "RSpec"
  end
  project_name "Rscons"
  merge_timeout 3600
end

if ENV["dist_specs"]
  require_relative "../test/rscons"
else
  require "rscons"
end
