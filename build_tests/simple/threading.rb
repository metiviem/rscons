class ThreadedTestBuilder < Rscons::Builder
  def run(options)
    if @command
      true
    else
      @command = ["ruby", "-e", %[sleep 1]]
      register_command("ThreadedTestBuilder #{@target}", @command)
    end
  end
end

class NonThreadedTestBuilder < Rscons::Builder
  def run(options)
    puts "NonThreadedTestBuilder #{@target}"
    sleep 1
    true
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
