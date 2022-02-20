variant "one"
variant "two", default: false

configure do
  if variant_enabled?("one")
    puts "one enabled"
  end
  if variant_enabled?("two")
    puts "two enabled"
  end
  if variant_enabled?("three")
    puts "three enabled"
  end
end
