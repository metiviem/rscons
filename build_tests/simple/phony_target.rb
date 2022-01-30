default do
  Environment.new do |env|
    env.add_builder(:Checker) do |params|
      unless @cache.up_to_date?(@target, :Checker, @sources, @env)
        puts "Checker #{@sources.first}" if @env.echo != :off
        @cache.register_build(@target, :Checker, @sources, @env)
      end
      true
    end
    env.Program("simple.exe", "simple.c")
    env.Checker(:checker, "simple.exe")
  end
end
