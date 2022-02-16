variant "debug"
variant "release", key: nil

with_variants do
  env "prog" do |env|
    if variant("debug")
      env["CPPDEFINES"] << "DEBUG"
    else
      env["CPPDEFINES"] << "NDEBUG"
    end
    env.Program("^/prog.exe", "prog.c")
  end
end
