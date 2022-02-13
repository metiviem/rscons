env do |env|
  env["MYSUFFIX"] = ".out"
  env.Program("simple${MYSUFFIX}", Dir["*.c"])
end
