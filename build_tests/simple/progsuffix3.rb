default do
  Environment.new do |env|
    env.Program("simple", Dir["*.c"], "PROGSUFFIX" => ".xyz")
  end
end
