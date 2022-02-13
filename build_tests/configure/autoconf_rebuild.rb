configure do
  check_c_compiler
  check_c_header "stdio.h"
end

env do |env|
  env.Program("simple.exe", "simple.c")
end
