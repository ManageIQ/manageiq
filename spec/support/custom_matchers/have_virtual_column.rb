RSpec::Matchers.define :have_virtual_column do |name, type|
  match do |klass|
    vcol = klass.virtual_columns_hash[name.to_s]
    vcol.should_not  be_nil
    vcol.type.should == type
    klass.instance_methods.include?(name.to_sym).should be_true
  end

  failure_message_for_should do |klass|
    "expected #{klass.name} to have virtual column #{name.inspect} with type #{type.inspect}"
  end

  failure_message_for_should_not do |klass|
    "expected #{klass.name} to not have virtual column #{name.inspect} with type #{type.inspect}"
  end

  description do
    "expect the object to have the virtual column"
  end
end
