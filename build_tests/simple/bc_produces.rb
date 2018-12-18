class MyObject < Rscons::Builder
  def produces?(target, source, env)
    target.end_with?(".o") and source.end_with?(".xyz")
  end

  def run(target, sources, cache, env, vars)
    cflags = env.expand_varref("${CFLAGS}", vars)
    vars = vars.merge(
      "CFLAGS" => cflags + %w[-x c],
      "CSUFFIX" => ".xyz")
    env.run_builder(env.builders["Object"], target, sources, cache, vars)
  end
end

build do
  Rscons::Environment.new do |env|
    env.add_builder(MyObject.new)
    File.open("test.xyz", "w") do |fh|
      fh.puts <<EOF
#include <stdio.h>
int main(int argc, char * argv[])
{
    printf("XYZ!\\n");
    return 0;
}
EOF
    env.Program("test", "test.xyz")
    end
  end
end
