build do
  Environment.new() do |env|
    env["LIBSUFFIX"] = %w[.aaaa .aaa]
    env.Library("one.aaaa", "one.c", "CPPFLAGS" => ["-DONE"])
    env.Library("two.aaa", "two.c")
    env.Program("two_sources.exe", %w[one.aaaa two.aaa])
  end
end
