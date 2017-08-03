Rscons::Environment.new do |env|
  env.echo = :command
  env.Install("inst.exe", "install.rb")
end

