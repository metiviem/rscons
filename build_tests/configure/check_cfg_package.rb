configure do
  check_cfg package: "mypackage"
end

Rscons::Environment.new(echo: :command) do |env|
  env.Program("myconfigtest", "simple.c")
end
