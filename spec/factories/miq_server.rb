FactoryBot.define do
  factory :miq_server do
    zone            { FactoryBot.build(:zone) }
    sequence(:name) { |n| "miq_server_#{seq_padded_for_sorting(n)}" }
    last_heartbeat  { Time.now.utc }
    status          { "started" }
    started_on      { Time.now.utc }
    stopped_on      { "" }
    version         { '9.9.9.9' }

    factory :miq_server_in_default_zone do
      zone          { FactoryBot.build(:zone, :name => "default") }
    end
  end
end
