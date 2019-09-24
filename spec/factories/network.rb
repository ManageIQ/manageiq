FactoryBot.define do
  factory :network do
    sequence(:ipaddress) { |n| ip_from_seq(n) }
  end
end
