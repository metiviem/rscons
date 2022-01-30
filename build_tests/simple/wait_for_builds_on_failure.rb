class Fail < Rscons::Builder
  def run(options)
    if @command
      finalize_command
    else
      wait_time = @env.expand_varref("${wait_time}", @vars)
      ruby_command = %[sleep #{wait_time}; exit 2]
      @command = %W[ruby -e #{ruby_command}]
      register_command("Fail #{@target}", @command)
    end
  end
end

default do
  Environment.new do |env|
    env.add_builder(Fail)
    4.times do |i|
      wait_time = i + 1
      env.Fail("foo_#{wait_time}", [], "wait_time" => wait_time.to_s)
    end
  end
end
