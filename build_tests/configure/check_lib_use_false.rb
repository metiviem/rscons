configure do
  check_lib "m", use: false
end

build do
  Environment.new(echo: :command) do |env|
    env.Copy("test1.c", "simple.c")
    env.Program("test2.exe", "test1.c")
  end
end
