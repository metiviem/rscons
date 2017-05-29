env = Rscons::Environment.new do |env|
  env.append('CPPPATH' => Dir['src/**/*/'].sort)
  env.build_dir("src", "build")
  env.build_root = "build_root"
  env.Program('build_dir.exe', Dir['src/**/*.c'])
end
