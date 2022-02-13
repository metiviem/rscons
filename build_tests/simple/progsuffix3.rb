env do |env|
  env.Program("simple", Dir["*.c"], "PROGSUFFIX" => ".xyz")
end
