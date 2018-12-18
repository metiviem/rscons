build do
  base_env = Environment.new do |env|
    env.n_threads = 165
  end

  my_env = base_env.clone

  puts my_env.n_threads
end
