configure do
  check_c_header "math.h", set_define: "HAVE_MATH_H"
  check_c_header "stdio.h", set_define: "HAVE_STDIO_H"
end

Rscons::Environment.new(echo: :command) do |env|
  env.Object("simple.o", "simple.c")
end
