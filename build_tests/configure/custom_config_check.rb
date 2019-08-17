configure do
  custom_check("Checking 'grep' version") do |op|
    stdout, stderr, status = op.log_and_test_command(%w[grep --version])
    should_fail = true
    if status != 0
      fail_message = "error executing grep"
    elsif stdout =~ /^grep \(GNU grep\) 1\./
      fail_message = "too old!"
      status = 1
    elsif stdout =~ /^grep \(GNU grep\) 2\./
      fail_message = "we'll work with it but you should upgrade"
      status = 1
      should_fail = false
      op.store_merge("CPPDEFINES" => "GREP_WORKAROUND")
    else
      op.store_append("CPPDEFINES" => "GREP_FULL")
    end
    op.complete(status, success_message: "good!", fail_message: fail_message, fail: should_fail)
  end
end

build do
  Environment.new do |env|
    puts env["CPPDEFINES"]
  end
end
