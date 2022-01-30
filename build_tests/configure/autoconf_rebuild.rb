configure do
  check_c_compiler
  check_c_header "stdio.h"
end

default do
  Environment.new do |env|
    env.Program("simple.exe", "simple.c")
  end
end
