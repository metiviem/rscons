build do
  Environment.new(echo: :command) do |env|
    env["ARCMD"] = %w[ar rcf ${_TARGET} ${_SOURCES}]
    env.Library("lib.a", Rscons.glob("*.c"))
  end
end
