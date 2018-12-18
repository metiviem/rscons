build do
  Environment.new do |env|
    env["MYSUFFIX"] = ".out"
    env.Program("simple${MYSUFFIX}", Dir["*.c"])
  end
end
