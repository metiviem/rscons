class ThreadedTestBuilder < Rscons::Builder
  def run(options)
    command = ["ruby", "-e", %[sleep 1]]
    Rscons::ThreadedCommand.new(
      command,
      short_description: "ThreadedTestBuilder #{@target}")
  end
  def finalize(options)
    true
  end
end

class NonThreadedTestBuilder < Rscons::Builder
  def run(options)
    puts "NonThreadedTestBuilder #{@target}"
    sleep 1
    @target
  end
end

build do
  Environment.new do |env|
    env.add_builder(ThreadedTestBuilder)
    env.add_builder(NonThreadedTestBuilder)
    env.ThreadedTestBuilder("a")
    env.ThreadedTestBuilder("b")
    env.ThreadedTestBuilder("c")
    env.NonThreadedTestBuilder("d")
  end
end
