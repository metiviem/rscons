base_env = Rscons::Environment.new do |env|
  env.n_threads = 165
end

my_env = base_env.clone

puts my_env.n_threads
