configure do
  check_c_header "not___found.h", set_define: "HAVE_NOT___FOUND_H"
end

env(echo: :command) do |env|
  env.Object("simple.o", "simple.c")
end
