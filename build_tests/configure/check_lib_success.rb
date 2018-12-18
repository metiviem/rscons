configure do
  check_lib "m"
end

build do
  Environment.new(echo: :command) do |env|
    env.Program("simple.exe", "simple.c")
  end
end
