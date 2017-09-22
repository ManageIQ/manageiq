FactoryGirl.define do
  factory :miq_server do
    transient do
      zone_name { FactoryGirl.build(:zone).name }
    end

    guid            { SecureRandom.uuid }
    zone            { FactoryGirl.build(:zone, :name => zone_name) }
    sequence(:name) { |n| "miq_server_#{seq_padded_for_sorting(n)}" }
    last_heartbeat  { Time.now.utc }
    status          "started"
    started_on      { Time.now.utc }
    stopped_on      ""
    version         '9.9.9.9'
  end
end
