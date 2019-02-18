class DebugBuilder < Rscons::Builder
  def run(options)
    if @command
      finalize_command
    else
      @command = %W[gcc -c -o #{@target} #{@sources.first}]
      if Rscons.vars["command_change"]
        @command += %w[-Wall]
      end
      if Rscons.vars["new_dep"]
        @sources += ["extra"]
      end
      if Rscons.vars["strict_deps1"]
        @sources += ["extra"]
        strict_deps = true
      end
      if Rscons.vars["strict_deps2"]
        @sources = ["extra"] + @sources
        strict_deps = true
      end
      if @cache.up_to_date?(@target, @command, @sources, @env, debug: true, strict_deps: strict_deps)
        true
      else
        register_command("#{name} #{target}", @command)
      end
    end
  end
end

build do
  Environment.new do |env|
    env.add_builder(DebugBuilder)
    if Rscons.vars["new_user_dep"]
      env.depends("foo.o", "new_dep")
    end
    env.DebugBuilder("foo.o", "simple.c")
  end
end
