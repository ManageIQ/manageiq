RSpec::Matchers.define :be_deleted do
  match do |object_instance|
    klass = object_instance.class
    expect(klass.exists?(:id => object_instance.id)).to be false
  end

  failure_message do |object_instance|
    "expected #{object_instance.class.name} to be deleted"
  end

  failure_message_when_negated do |object_instance|
    "expected #{object_instance.class.name} to exist"
  end
end
