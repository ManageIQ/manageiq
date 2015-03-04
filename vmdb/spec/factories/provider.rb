FactoryGirl.define do
  factory :provider do
    sequence(:name) { |n| "provider_#{seq_padded_for_sorting(n)}" }
    guid            { MiqUUID.new_guid }
  end

  factory :provider_foreman, :class => "ProviderForeman", :parent => :provider do
    url "example.com"

    after(:build) do |provider|
      provider.authentications << FactoryGirl.build(:authentication,
                                                    :userid   => "admin",
                                                    :password => "smartvm")
    end
  end
end
