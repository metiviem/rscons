default do
  Environment.new do |env|
    env["PROGSUFFIX"] = ".out"
    env.Program("simple", Dir["*.c"])
  end
end
