configure do
  check_c_compiler "foo123c", fail: false, on_fail: "Install the foo123 package"
  check_d_compiler "foo123d", fail: false
  check_cxx_compiler "foo123cxx", on_fail: lambda {puts "Install the foo123cxx package"}
end
