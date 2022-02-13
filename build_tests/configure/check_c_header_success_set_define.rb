configure do
  check_c_header "string.h", set_define: "HAVE_STRING_H"
end

env(echo: :command) do |env|
  env.Object("simple.o", "simple.c")
end
