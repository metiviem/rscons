class TestBuilder < Rscons::Builder
  def run(options)
    target, sources, cache, env = options.values_at(:target, :sources, :cache, :env)
    command = Rscons::VarSet.new("A" => "a", "B" => "b")
    unless cache.up_to_date?(target, command, sources, env)
      File.open(target, "w") do |fh|
        fh.puts("hi")
      end
      msg = "#{self.class.name} #{target}"
      env.print_builder_run_message(msg, msg)
      cache.register_build(target, command, sources, env)
    end
    target
  end
end

Rscons::Environment.new do |env|
  env.add_builder(TestBuilder.new)
  env.TestBuilder("foo")
end
