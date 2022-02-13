configure do
  check_lib "m", check_libpath: ["./usr1"]
  check_lib "frobulous", check_libpath: ["./usr2"]
end

env(echo: :command) do |env|
  env.Program("simple.exe", "simple.c")
end
