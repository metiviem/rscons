build do
  Environment.new do |env|
    env["build_root"] = env.build_root
    env["inc_h"] = "inc.h"

    env.Copy("copy_inc.h", "${inc_h}")
    env.depends("program.o", "${inc_h}")
    env.Object("program.o", "program.c")
    env.Program("program.exe", ["program.o", "inc.c"])

    env.Command("inc.c",
                [],
                "CMD" => %w[ruby gen.rb ${_TARGET}],
                "CMD_DESC" => "Generating")
    env.produces("inc.c", "inc.h")
  end
end
