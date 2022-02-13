env do |env|
  env.Directory("copy")
  env.Copy("copy", "copy_directory.rb")

  env.Copy("noexist/src", "src")

  env.Directory("exist/src")
  env.Copy("exist/src", "src")
end
