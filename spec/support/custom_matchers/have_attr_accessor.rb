RSpec::Matchers.define :have_attr_accessor do |field_name|
  match do |object_instance|
    object_instance.respond_to?(field_name) && object_instance.respond_to?("#{field_name}=")
  end

  failure_message do |object_instance|
    "expected attr_accessor #{field_name} for #{object_instance}"
  end

  failure_message_when_negated do |object_instance|
    "expected attr_accessor #{field_name} not to be defined for #{object_instance}"
  end
end
