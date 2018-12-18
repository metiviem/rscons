build do
  Environment.new(echo: :command) do |env|
    env["DEPFILESUFFIX"] = ".deppy"
    env.Object("simple.o", "simple.c")
  end
end
