configure do
  check_c_compiler
end
env do |env|
  puts "Prefix is #{Task["configure"]["prefix"]}"
end
