configure do
  check_cfg package: "mypackage", use: "myp"
end

build do
  Environment.new(echo: :command) do |env|
    env.Copy("myconfigtest1.c", "simple.c")
    env.Program("myconfigtest1.exe", "myconfigtest1.c")
  end

  Environment.new(echo: :command, use: "myp") do |env|
    env.Copy("myconfigtest2.c", "simple.c")
    env.Program("myconfigtest2.exe", "myconfigtest2.c")
  end
end
