build do
  sh "foobar42", continue: true
  sh "echo", "continued"
end
