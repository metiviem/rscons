Rscons::Environment.new do |env|
  env.append('CPPPATH' => Rscons.glob('src/**'))
  env.build_dir("src2", "build")
  env.Program('build_dir.exe', Rscons.glob('src/**/*.c'))
end
