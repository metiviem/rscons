configure do
  check_cxx_compiler "clang++", use: "clang"
  check_cxx_compiler
end

env "t1" do |env|
  env.Program("test_gcc.exe", "simple.cc")
end

env "t2", use: "clang" do |env|
  env.Program("test_clang.exe", "simple.cc")
end
