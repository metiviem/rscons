base_env = env do |env|
  env.n_threads = 165
end

my_env = base_env.clone do |env|
  puts env.n_threads
end
