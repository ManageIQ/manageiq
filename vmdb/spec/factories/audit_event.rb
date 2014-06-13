FactoryGirl.define do
  factory :audit_event do
    event            "something"
    message          "foo"
    severity         "info"
    status           "success"
  end
end
