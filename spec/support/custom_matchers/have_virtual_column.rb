RSpec::Matchers.define :have_virtual_column do |name, type|
  match do |klass|
    expect(klass.has_attribute?(name)).to be_truthy
    expect(klass.virtual_attribute?(name)).to be_truthy
    expect(klass.type_for_attribute(name).type).to eq(type)
    klass.instance_methods.include?(name.to_sym)
  end

  failure_message do |klass|
    "expected #{klass.name} to have virtual column #{name.inspect} with type #{type.inspect}"
  end

  failure_message_when_negated do |klass|
    "expected #{klass.name} to not have virtual column #{name.inspect} with type #{type.inspect}"
  end

  description do
    "expect the object to have the virtual column"
  end
end
