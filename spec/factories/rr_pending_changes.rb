FactoryGirl.define do
  factory :rr_pending_change do
    change_table "miq_servers"
    sequence(:change_key) { |n| "id|#{n}" }
    change_type "U"
    change_time "2015-11-10 19:19:28"
  end
end
