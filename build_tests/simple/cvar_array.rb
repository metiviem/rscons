Rscons::Environment.new do |env|
  env["sources"] = Rscons.glob("*.c")
  env.Program("simple.exe", "${sources}")
end
