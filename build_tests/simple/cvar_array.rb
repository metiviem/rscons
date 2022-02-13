env do |env|
  env["sources"] = glob("*.c")
  env.Program("simple.exe", "${sources}")
end
