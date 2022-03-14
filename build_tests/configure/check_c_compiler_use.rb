configure do
  check_c_compiler "clang", use: "clang"
  check_c_compiler
end

env "t1" do |env|
  env.Program("test_gcc.exe", "simple.c")
end

env "t2", use: "clang" do |env|
  env.Program("test_clang.exe", "simple.c")
end
