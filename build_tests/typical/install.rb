project_name "install_test"

build do
  Environment.new do |env|
    env["CPPPATH"] += glob("src/**")
    env.Program("^/program.exe", glob("src/**/*.c"))
    env.InstallDirectory("${prefix}/bin")
    env.Install("${prefix}/bin", "^/program.exe")
    env.InstallDirectory("${prefix}/share")
    env.Install("${prefix}/share/proj/install.rb", "install.rb")
    env.Install("${prefix}/mult", ["install.rb", "copy.rb"])
    env.Install("${prefix}/src", "src")
  end
end
