class StrictBuilder < Rscons::Builder
  def run(options)
    if @command
      finalize_command
    else
      @command = %W[gcc -o #{@target}] + @sources.sort
      if @cache.up_to_date?(@target, @command, @sources, @env, strict_deps: true)
        true
      else
        register_command("#{name} #{@target}", @command)
      end
    end
  end
end

default do
  Environment.new(echo: :command) do |env|
    env.add_builder(StrictBuilder)
    env.Object("one.o", "one.c", "CCFLAGS" => %w[-DONE])
    env.Object("two.o", "two.c")
    sources = File.read("sources", mode: "rb").split(" ")
    env.StrictBuilder("program.exe", sources)
  end
end
