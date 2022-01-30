default do
  Environment.new do |env|
    env.Command("inc.c",
                [],
                "CMD" => %w[ruby gen.rb ${_TARGET}],
                "CMD_DESC" => "Generating")
    env["build_root"] = env.build_root
    env["inc_c"] = "inc.c"
    env.Object("program.o", "program.c")
    env.build_after("program.o", "${inc_c}")
    env.Program("program.exe", ["program.o", "inc.c"])
  end
end
