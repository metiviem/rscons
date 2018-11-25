class TestBuilder < Rscons::Builder
  def run(target, sources, cache, env, vars)
    target
  end
end
Rscons::Environment.new do |env|
  env.add_builder(TestBuilder.new)
  env.TestBuilder("file")
end
