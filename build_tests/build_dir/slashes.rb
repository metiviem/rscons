Rscons::Environment.new do |env|
  env.append("CPPPATH" => Dir["src/**/*/"].sort)
  env.build_dir("src/one/", "build_one/")
  env.build_dir("src/two", "build_two")
  env.Program("build_dir.exe", Dir["src/**/*.c"])
end
