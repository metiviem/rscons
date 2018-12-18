class ThreadedTestBuilder < Rscons::Builder
  def run(options)
    command = ["ruby", "-e", %[sleep 1]]
    Rscons::ThreadedCommand.new(
      command,
      short_description: "ThreadedTestBuilder #{options[:target]}")
  end
  def finalize(options)
    true
  end
end

class NonThreadedTestBuilder < Rscons::Builder
  def run(options)
    puts "NonThreadedTestBuilder #{options[:target]}"
    sleep 1
    options[:target]
  end
end

build do
  Environment.new do |env|
    env.add_builder(ThreadedTestBuilder.new)
    env.add_builder(NonThreadedTestBuilder.new)
    env.ThreadedTestBuilder("a")
    env.ThreadedTestBuilder("b")
    env.ThreadedTestBuilder("c")
    env.NonThreadedTestBuilder("d")
  end
end
