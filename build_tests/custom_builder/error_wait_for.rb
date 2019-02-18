build do
  Environment.new do |env|
    env.add_builder(:MyBuilder) do |options|
      wait_for(1)
    end
    env.MyBuilder("foo")
  end
end
