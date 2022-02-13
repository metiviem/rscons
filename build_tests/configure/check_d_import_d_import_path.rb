configure do
  check_d_compiler
  check_d_import "std.stdio", check_d_import_path: ["./usr1"]
  check_d_import "frobulous", check_d_import_path: ["./usr2"]
end

env do |env|
  env.Object("test.o", "test.d")
end
