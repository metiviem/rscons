configure do
  check_d_compiler "ldc2"
end

env(echo: :command) do |env|
  env.Program("hello-d.exe", glob("*.d"))
end
