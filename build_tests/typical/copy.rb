build do
  Rscons::Environment.new do |env|
    env.Copy("inst.exe", "copy.rb")
  end
end
