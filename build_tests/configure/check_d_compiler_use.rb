configure do
  check_d_compiler "ldc2", use: "ldc2"
  check_d_compiler
end

env "t1" do |env|
  env.Program("test_gcc.exe", "simple.d")
end

env "t2", use: "ldc2" do |env|
  env.Program("test_ldc2.exe", "simple.d")
end
