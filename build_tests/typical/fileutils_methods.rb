default do
  mkdir "foo"
  cd "foo" do
    mkdir_p ["bar/baz", "bar/booz"]
  end
  mv "foo/bar", "foobar"
  rmdir "foo"
  touch "foobar/booz/a.txt"
  cp "foobar/booz/a.txt", "foobar/baz/b.txt"
  rm_rf "foobar/booz"
end
