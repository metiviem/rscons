build do
  Rscons::Environment.new do |env|
    env.Object("simple.o", "simple.c")
    env.Command("simple.txt",
                "simple.o",
                "CMD" => %w[objdump --disassemble --source ${_SOURCES}],
                "CMD_STDOUT" => "${_TARGET}",
                "CMD_DESC" => "My Disassemble")
  end
end
