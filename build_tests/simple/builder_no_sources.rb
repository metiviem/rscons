class TestBuilder < Rscons::Builder
  def run(options)
    true
  end
end

env do |env|
  env.add_builder(TestBuilder)
  env.TestBuilder("file")
end
