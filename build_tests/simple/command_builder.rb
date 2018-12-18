build do
  Environment.new do |env|
    command = %W[gcc -o ${_TARGET} ${_SOURCES}]
    env.Command("simple.exe",
                "simple.c",
                "CMD" => command,
                "CMD_DESC" => "BuildIt")
  end
end
