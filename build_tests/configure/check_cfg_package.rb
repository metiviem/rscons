configure do
  check_cfg package: "mypackage"
end

env(echo: :command) do |env|
  env.Program("myconfigtest", "simple.c")
end
