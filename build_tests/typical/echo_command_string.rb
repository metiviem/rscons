class MyBuilder < Rscons::Builder
  def run(options)
    env, target = options.values_at(:env, :target)
    env.print_builder_run_message("MyBuilder #{target}", "MyBuilder #{target} command")
    target
  end
end

build do
  Environment.new do |env|
    env.echo = :command
    env.add_builder(MyBuilder)
    env.MyBuilder("foo")
  end
end
