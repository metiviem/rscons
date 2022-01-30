task "one" do
  puts "one"
end

task "two", deps: ["one", "three"] do
  puts "two"
end

task "three", desc: "Task three" do
  puts "three"
end

task "four", desc: "Task four", params: [
  param("myparam", "defaultvalue", true, "My special parameter"),
  param("myp2", nil, false, "My parameter 2"),
] do |task, params|
  puts "four"
  puts "myparam:" + params["myparam"].inspect
  puts "myp2:" + params["myp2"].inspect
end

task "five" do
  puts "four myparam value is #{Task["four"]["myparam"]}"
end

task "six" do |task|
  puts task["nope"]
end
