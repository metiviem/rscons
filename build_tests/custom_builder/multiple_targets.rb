class CHGen < Rscons::Builder
  def run(target, sources, cache, env, vars)
    c_fname = target
    h_fname = target.sub(/\.c$/, ".h")
    unless cache.up_to_date?([c_fname, h_fname], "", sources, env)
      puts "CHGen #{c_fname}"
      File.open(c_fname, "w") {|fh| fh.puts "int THE_VALUE = 42;"}
      File.open(h_fname, "w") {|fh| fh.puts "extern int THE_VALUE;"}
      cache.register_build([c_fname, h_fname], "", sources, env)
    end
    target
  end
end

build do
  Environment.new do |env|
    env.add_builder(CHGen.new)
    env.CHGen("inc.c", ["program.c"])
    env.Program("program.exe", %w[program.c inc.c])
  end
end
