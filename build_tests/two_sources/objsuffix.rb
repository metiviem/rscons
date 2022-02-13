env do |env|
  env["OBJSUFFIX"] = %w[.oooo .ooo]
  env.Object("one.oooo", "one.c", "CPPFLAGS" => ["-DONE"])
  env.Object("two.ooo", "two.c")
  env.Program("two_sources.exe", %w[one.oooo two.ooo])
end
