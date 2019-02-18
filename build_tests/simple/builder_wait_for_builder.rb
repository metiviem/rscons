class MyObject < Rscons::Builder
  def run(options)
    if @builder
      if File.exists?(@target)
        true
      else
        false
      end
    else
      @env.print_builder_run_message("#{name} #{@target}", nil)
      @builder = @env.Object(@target, @sources, @vars)
      wait_for(@builder)
    end
  end
end

build do
  Environment.new do |env|
    env.add_builder(MyObject)
    env.MyObject("simple.o", "simple.c")
    env.Program("simple.exe", "simple.o")
  end
end
