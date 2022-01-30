class MySource < Rscons::Builder
  def run(options)
    File.open(@target, 'w') do |fh|
      fh.puts <<EOF
#define THE_VALUE 678
EOF
    end
    true
  end
end

default do
  env = Environment.new do |env|
    env["hdr"] = "inc.h"
    env["src"] = "program.c"
    env.add_builder(MySource)
    env.MySource('${hdr}')
    env.Program('program.exe', "${src}")
  end
end
