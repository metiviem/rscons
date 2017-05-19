Rscons::Environment.new do |env|
  env["CXXSUFFIX"] = %w[.cccc .cc]
  env["CXXFLAGS"] += %w[-x c++]
  env.Program("simple.exe", Dir["*.cc"] + Dir["*.cccc"])
end
