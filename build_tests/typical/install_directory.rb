build do
  Environment.new do |env|
    env.Directory("inst")
    env.Install("inst", "install_directory.rb")

    env.Install("noexist/src", "src")

    env.Directory("exist/src")
    env.Install("exist/src", "src")
  end
end
