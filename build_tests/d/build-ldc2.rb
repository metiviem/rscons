configure do
  check_d_compiler "ldc2"
end

build do
  Environment.new(echo: :command) do |env|
    env.Program("hello-d.exe", glob("*.d"))
  end
end
