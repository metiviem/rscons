configure do
  check_cxx_header "string.h", check_cpppath: ["./usr1"]
  check_cxx_header "frobulous.h", check_cpppath: ["./usr2"]
end

build do
  Environment.new do |env|
    env.Object("test.o", "test.cc")
  end
end
