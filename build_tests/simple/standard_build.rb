build do
  class MyCommand < Rscons::Builder
    def run(target, sources, cache, env, vars)
      vars = vars.merge({
        "_TARGET" => target,
        "_SOURCES" => sources,
      })
      command = env.build_command("${CMD}", vars)
      cmd_desc = vars["CMD_DESC"] || "MyCommand"
      standard_build("#{cmd_desc} #{target}", target, command, sources, env, cache)
    end
  end

  Environment.new do |env|
    env.add_builder(MyCommand.new)
    command = %w[gcc -c -o ${_TARGET} ${_SOURCES}]
    env.MyCommand("simple.o", "simple.c", "CMD" => command)
  end
end
