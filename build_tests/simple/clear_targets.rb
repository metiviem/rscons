Rscons::Environment.new do |env|
  env.Program("simple.exe", "simple.c")
  env.clear_targets
end
