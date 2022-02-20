variant "debug", default: false
variant "release"

with_variants do
  env "prog" do |env|
    env.Program("^/prog.exe", "prog.c")
  end
end
