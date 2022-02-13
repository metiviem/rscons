configure do
  check_c_header "string.h", check_cpppath: ["./usr1"]
  check_c_header "frobulous.h", check_cpppath: ["./usr2"]
end

env do |env|
  env.Object("test.o", "test.c")
end
