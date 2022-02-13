base_env = env do |env|
  env["CPPPATH"] += glob("src/**")
end

base_env.clone "typical" do |env|
  env.Program("^/typical.exe", glob("src/**/*.c"))
end
