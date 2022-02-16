variant_group "desktop-environment" do
  variant "kde"
  variant "gnome"
end

variant_group "debug" do
  variant "debug"
  variant "release"
end

with_variants do
  env "prog" do |env|
    if variant("kde")
      env["CPPDEFINES"] << "KDE"
    end
    if variant("gnome")
      env["CPPDEFINES"] << "GNOME"
    end
    if variant("debug")
      env["CPPDEFINES"] << "DEBUG"
    end
    if variant("release")
      env["CPPDEFINES"] << "NDEBUG"
    end
    env.Program("^/prog.exe", "prog.c")
  end
end
