Rscons::Environment.new do |env|
  env.Command("inc.c",
              [],
              "CMD" => %w[ruby gen.rb ${_TARGET}],
              "CMD_DESC" => "Generating")
  env.build_after("#{env.build_root}/program.o", "inc.c")
  env.Program("program.exe", ["program.c", "inc.c"])
end
