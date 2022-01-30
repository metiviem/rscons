class MyBuilder < Rscons::Builder
  def run(options)
    if @thread
      true
    else
      print_run_message("#{name} #{target}", nil)
      @thread = Thread.new do
        sleep 2
        FileUtils.touch(@target)
      end
      wait_for(@thread)
    end
  end
end

default do
  Environment.new do |env|
    env.add_builder(MyBuilder)
    env.MyBuilder("foo")
  end
end
