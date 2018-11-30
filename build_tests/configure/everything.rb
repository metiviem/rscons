project_name "configure test"
autoconf false
configure do
  check_c_compiler
  check_cxx_compiler
  check_d_compiler
  check_cfg package: "mypackage"
  check_c_header "stdio.h"
  check_cxx_header "iostream"
  check_d_import "std.stdio"
  check_lib "m"
  check_program "ls"
end
