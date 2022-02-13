class MyBuilder < Rscons::Builder
  def run(options)
    print_run_message("MyBuilder #{@target}", "MyBuilder #{@target} command")
    true
  end
end

env do |env|
  env.echo = :command
  env.add_builder(MyBuilder)
  env.MyBuilder("foo")
end
