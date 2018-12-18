build do
  Rscons::Environment.new do |env|
    env.Install("inst.exe", "install.rb")
  end
end
