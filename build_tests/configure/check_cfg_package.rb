configure do
  check_cfg package: "mypackage"
end

build do
  Rscons::Environment.new(echo: :command) do |env|
    env.Program("myconfigtest", "simple.c")
  end
end
