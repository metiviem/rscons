default do
  Environment.new do |env|
    env.Copy("dest", ["copy.rb", "copy_multiple.rb"])
  end
end
