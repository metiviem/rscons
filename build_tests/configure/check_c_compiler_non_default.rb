configure do
  check_c_compiler "clang"
end
env do |env|
  env.Program("simple.exe", "simple.c")
end
