build do
  Environment.new do |env|
    env.Program("test.exe", Rscons.glob("*.c"), direct: true)
  end
end
