FactoryGirl.define do
  factory :provider_foreman do
    url "example.com"
    after(:build) do |provider|
      provider.authentications << FactoryGirl.build(:authentication,
                                                    :userid   => "admin",
                                                    :password => "smartvm")
    end
  end
end
