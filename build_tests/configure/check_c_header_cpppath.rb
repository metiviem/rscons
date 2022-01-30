configure do
  check_c_header "string.h", check_cpppath: ["./usr1"]
  check_c_header "frobulous.h", check_cpppath: ["./usr2"]
end

default do
  Environment.new do |env|
    env.Object("test.o", "test.c")
  end
end
