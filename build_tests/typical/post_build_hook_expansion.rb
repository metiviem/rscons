build do
  Rscons::Environment.new do |env|
    env["CPPPATH"] << "src/two"
    env.Object("one.o", "src/one/one.c")
    env.add_post_build_hook do |build_op|
      if build_op[:target] == "one.o"
        env["MODULE"] = "two"
        env.Object("${MODULE}.o", "src/${MODULE}/${MODULE}.c")
      end
    end
  end
end
