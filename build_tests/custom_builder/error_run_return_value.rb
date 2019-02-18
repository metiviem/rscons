build do
  Environment.new do |env|
    env.add_builder(:MyBuilder) do |options|
      "hi"
    end
    env.MyBuilder("foo")
  end
end
