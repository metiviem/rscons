project_name "install_test"

configure do
end

env do |env|
  env["CPPPATH"] += glob("src/**")

  task "build" do
    env.Program("^/program.exe", glob("src/**/*.c"))
  end

  task "install", depends: "build" do
    env.InstallDirectory("${configure:prefix}/bin")
    env.Install("${configure:prefix}/bin", "^/program.exe")
    env.InstallDirectory("${configure:prefix}/share")
    env.Install("${configure:prefix}/share/proj/install.rb", "install.rb")
    env.Install("${configure:prefix}/mult", ["install.rb", "copy.rb"])
    env.Install("${configure:prefix}/src", "src")
  end
end

default(depends: "build")
