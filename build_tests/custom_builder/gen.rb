sleep 1.0
c_file = ARGV.first
h_file = File.basename(c_file, ".c") + ".h"
File.open(c_file, "w") do |fh|
  fh.puts
end
File.open(h_file, "w") do |fh|
  fh.puts("#define THE_VALUE 191")
end
