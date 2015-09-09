FactoryGirl.define do
  factory :miq_server do
    guid            { MiqUUID.new_guid }
    zone            { FactoryGirl.build(:zone) }
    sequence(:name) { |n| "miq_server_#{seq_padded_for_sorting(n)}" }
    last_heartbeat  { Time.now.utc }
    status          "started"
    started_on      { Time.now.utc }
    stopped_on      ""
    version         '9.9.9.9'

    trait :my_server do
      after(:create) do |ms|
        MiqServer.stub(:my_guid).and_return(ms.guid)
        MiqServer.my_server_clear_cache
      end
    end
  end
end
