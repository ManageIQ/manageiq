FactoryGirl.define do
  factory :foreman_provider, :class => 'ProviderForeman' do
    url "example.com"
    after(:build) do |provider|
      provider.authentications << FactoryGirl.build(:authentication,
                                                    :userid   => "admin",
                                                    :password => "smartvm")
    end
  end
end
