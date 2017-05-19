class MySource < Rscons::Builder
  def run(target, sources, cache, env, vars)
    File.open(target, 'w') do |fh|
      fh.puts <<EOF
#define THE_VALUE 678
EOF
    end
    target
  end
end

env = Rscons::Environment.new do |env|
  env["hdr"] = "inc.h"
  env["src"] = "program.c"
  env.add_builder(MySource.new)
  env.MySource('${hdr}')
  env.Program('program.exe', "${src}")
end
