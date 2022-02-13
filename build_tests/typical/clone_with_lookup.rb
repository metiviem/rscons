env "first" do |env|
  env["CPPPATH"] += glob("src/**")
end

Environment["first"].clone "typical" do |env|
  env.Program("^/typical.exe", glob("src/**/*.c"))
end
