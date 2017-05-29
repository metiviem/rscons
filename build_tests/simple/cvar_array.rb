Rscons::Environment.new do |env|
  env["sources"] = Dir["*.c"].sort
  env.Program("simple.exe", "${sources}")
end
