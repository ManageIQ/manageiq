begin
  tc = $evm.new_object('Miq::TestModule::TestClass', 76)
  $evm.root['param'] = tc.param
rescue => err
  puts "\#{err.class}:\#{err.to_s}"
  $evm.root['error'] = err.to_s
end
