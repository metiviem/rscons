default do
  env = Environment.new do |env|
    env["CFLAGS"] += %w[-O2 -fomit-frame-pointer]
    env[:foo] = :bar
  end
  env.dump
end
