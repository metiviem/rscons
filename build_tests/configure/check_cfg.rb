configure do
  check_cfg program: "my-config"
end

env(echo: :command) do |env|
  env.Program("myconfigtest", "simple.c")
end
