class TestBuilder < Rscons::Builder
  def run(options)
    if @command
      true
    else
      if @target == "two"
        return false unless File.exists?("one")
      end
      wait_time = @env.expand_varref("${wait_time}", @vars)
      @command = ["ruby", "-e", "require 'fileutils'; sleep #{wait_time}; FileUtils.touch('#{@target}');"]
      register_command("TestBuilder", @command)
    end
  end
end

env do |env|
  env.add_builder(TestBuilder)
  one = env.TestBuilder("one", [], "wait_time" => "3")
  two = env.TestBuilder("two", [], "wait_time" => "0")
  env.depends(two, one)
end
