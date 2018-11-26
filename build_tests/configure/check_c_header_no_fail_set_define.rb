configure do
  check_c_header "not___found.h", fail: false, set_define: "HAVE_NOT___FOUND_H"
end

Rscons::Environment.new(echo: :command) do |env|
  env.Object("simple.o", "simple.c")
end
