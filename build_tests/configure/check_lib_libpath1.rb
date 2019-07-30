build do
  Environment.new(echo: :command) do |env|
    env.Library("usr2/libfrobulous.a", "two.c")
  end
end
