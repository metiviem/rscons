env do |env|
  env.Program('simple.exe', Dir['*.c'])
end

clean do
  puts "custom clean action"
end
