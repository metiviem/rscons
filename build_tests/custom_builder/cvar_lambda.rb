class MySource < Rscons::Builder
  def run(target, sources, cache, env, vars)
    File.open(target, 'w') do |fh|
      fh.puts <<EOF
#define THE_VALUE #{env.expand_varref("${the_value}")}
EOF
    end
    target
  end
end

build do
  e1 = Rscons::Environment.new do |env|
    env.add_builder(MySource.new)
    env["one"] = "5"
    env[:cfg] = {val: "9"}
    env["two"] = lambda do |args|
      args[:env][:cfg][:val]
    end
    env["the_value"] = lambda do |args|
      "${one}${two}78"
    end
  end

  e1.clone do |env|
    env[:cfg][:val] = "6"
    env.MySource('inc.h', [])
    env.Program('program.exe', Dir['*.c'])
  end
end
