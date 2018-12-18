build do
  Rscons::Environment.new do |env|
    env.Program("simple", Dir["*.c"], "PROGSUFFIX" => ".xyz")
  end
end
