build do
  Environment.new do |env|
    env.Preprocess("simplepp.cc", "simple.cc")
    env.Program("simple.exe", "simplepp.cc")
  end
end
