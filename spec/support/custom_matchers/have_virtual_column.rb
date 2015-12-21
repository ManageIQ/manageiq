RSpec::Matchers.define :have_virtual_column do |name, type|
  match do |klass|
    vcol = klass.virtual_columns_hash[name.to_s]
    expect(vcol).to_not be_nil
    expect(vcol.type).to eq(type)
    klass.instance_methods.include?(name.to_sym)
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
