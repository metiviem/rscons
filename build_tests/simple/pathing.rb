path_prepend "path_prepend"
path_append "path_append"

build do
  Environment.new do |env|
    system("flex")
    system("foobar")
    env.Object("simple.o", "simple.c")
  end
end
