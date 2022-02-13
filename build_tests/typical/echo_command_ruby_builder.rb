env do |env|
  env.echo = :command
  env.Copy("copy.rb", "echo_command_ruby_builder.rb")
end
