configure params: [
  param("with-xyz", "xyz", true, "Set xyz"),
  param("flag", nil, false, "Set flag"),
] do
  check_c_compiler
end

default do
  puts "xyz: #{Task["configure"]["with-xyz"]}"
  puts "flag: #{Task["configure"]["flag"].inspect}"
end
