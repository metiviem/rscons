class ThreadedTestBuilder < Rscons::Builder
  def run(options)
    if @command
      puts "#{@target} finished"
      true
    else
      @command = ["ruby", "-e", %[sleep #{@vars["delay"]}]]
      register_command("ThreadedTestBuilder #{@target}", @command)
    end
  end
end

default do
  Environment.new do |env|
    env.add_builder(ThreadedTestBuilder)
    env.ThreadedTestBuilder("T3", [], "delay" => 3)
    env.ThreadedTestBuilder("T2", [], "delay" => 1.0)
    env.ThreadedTestBuilder("T1", [], "delay" => 0.5)
    env.barrier
    env.ThreadedTestBuilder("T6", [], "delay" => 1.5)
    env.ThreadedTestBuilder("T5", [], "delay" => 1.0)
    env.ThreadedTestBuilder("T4", [], "delay" => 0.5)
  end
end
