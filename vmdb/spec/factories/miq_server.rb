FactoryGirl.define do
  factory :miq_server do
    sequence(:name) { |n| "miq_server_#{n}" }
    last_heartbeat  { Time.now.utc }
    status          "started"
    started_on      { Time.now.utc }
    stopped_on      ""
    version         '9.9.9.9'

    after(:create) do |s|
      MiqQueue.destroy_all(
        :class_name  => "User",
        :method_name => "sync_admin_password",
        :server_guid => s.guid
      )
    end
  end

  factory :miq_server_master, :parent => :miq_server do
    is_master      true
  end

  factory :miq_server_not_master, :parent => :miq_server do
    is_master      false
  end
end
