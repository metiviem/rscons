require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
  project_name "Rscons"
  merge_timeout 3600
end

require "rscons"
