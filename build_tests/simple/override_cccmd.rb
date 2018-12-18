build do
  Environment.new(echo: :command) do |env|
    env.Object("simple.o", "simple.c",
               "CCCMD" => %w[${CC} -c -o ${_TARGET} -Dfoobar ${_SOURCES}])
  end
end
