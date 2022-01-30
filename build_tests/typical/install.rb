project_name "install_test"

Environment.new do |env|
  env["CPPPATH"] += glob("src/**")

  task "build" do
    env.Program("^/program.exe", glob("src/**/*.c"))
  end

  task "install", deps: "build" do
    env.InstallDirectory("${prefix}/bin")
    env.Install("${prefix}/bin", "^/program.exe")
    env.InstallDirectory("${prefix}/share")
    env.Install("${prefix}/share/proj/install.rb", "install.rb")
    env.Install("${prefix}/mult", ["install.rb", "copy.rb"])
    env.Install("${prefix}/src", "src")
  end
end

default(deps: "build")
