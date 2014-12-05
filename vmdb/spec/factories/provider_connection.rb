FactoryGirl.define do
  factory :provider_connection do
    sequence(:name)      { |n| "p_conn_#{seq_padded_for_sorting(n)}" }
    sequence(:hostname)  { |n| "p_conn_#{seq_padded_for_sorting(n)}" }
    sequence(:ipaddress) { |n| "192.168.123.12"}
  end

  factory :provider_connection_with_authentication, :parent => :provider_connection do
    after(:create) do |x|
      x.authentications << FactoryGirl.create(:authentication)
      # x.authentications = [FactoryGirl.build(:authentication, :resource => x)]
    end
  end
end