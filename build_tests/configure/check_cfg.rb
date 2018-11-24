configure do
  check_cfg program: "my-config"
end

Rscons::Environment.new(echo: :command) do |env|
  env.Program("myconfigtest", "simple.c")
end
