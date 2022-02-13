env do |env|
  env.Preprocess("simplepp.c", "simple.c")
  env.Program("simple.exe", "simplepp.c")
end
