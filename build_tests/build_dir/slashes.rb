Rscons::Environment.new do |env|
  env.append("CPPPATH" => Rscons.glob("src/**"))
  env.build_dir("src/one/", "build_one/")
  env.build_dir("src/two", "build_two")
  env.Program("build_dir.exe", Rscons.glob("src/**/*.c"))
end
