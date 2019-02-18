class TestBuilder < Rscons::Builder
  def run(options)
    true
  end
end
build do
  Environment.new do |env|
    env.add_builder(TestBuilder)
    env.TestBuilder("file")
  end
end
