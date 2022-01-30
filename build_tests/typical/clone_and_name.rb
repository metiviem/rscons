default do
  base_env = Environment.new do |env|
    env["CPPPATH"] += glob("src/**")
  end

  base_env.clone(name: "typical") do |env|
    env.Program("^/typical.exe", glob("src/**/*.c"))
  end
end
