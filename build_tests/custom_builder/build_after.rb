build do
  Rscons::Environment.new do |env|
    env.Command("inc.c",
                [],
                "CMD" => %w[ruby gen.rb ${_TARGET}],
                "CMD_DESC" => "Generating")
    env["build_root"] = env.build_root
    env["inc_c"] = "inc.c"
    env.build_after("${build_root}/program.o", "${inc_c}")
    env.Program("program.exe", ["program.c", "inc.c"])
  end
end
