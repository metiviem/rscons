build do
  Environment.new(echo: :command) do |env|
    env.Object("main.o", "main.d")
    env.Object("mod.o", "mod.d")
    env.Program("hello-d.exe", ["main.o", "mod.o"])
  end
end
