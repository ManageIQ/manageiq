FactoryGirl.define do
  factory :chargeback_rate do
    guid        { MiqUUID.new_guid }
    description 'foo'
  end
end
