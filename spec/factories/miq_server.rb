FactoryGirl.define do
  factory :miq_server do
    sequence(:name) { |n| "miq_server_#{seq_padded_for_sorting(n)}" }
    last_heartbeat  { Time.now.utc }
    status          "started"
    started_on      { Time.now.utc }
    stopped_on      ""
    version         '9.9.9.9'
  end

  factory :miq_server_master, :parent => :miq_server do
    is_master      true
  end

  factory :miq_server_not_master, :parent => :miq_server do
    is_master      false
  end
end
