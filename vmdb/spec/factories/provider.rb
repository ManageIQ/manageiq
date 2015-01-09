FactoryGirl.define do
  factory :foreman_provider, :class => 'ProviderForeman' do
    ignore do
      userid   "admin"
      password "smartvm"
    end
    after(:build) do |provider, evaluator|
      provider.authentications << FactoryGirl.build(:authentication,
                                                    :userid   => evaluator.userid,
                                                    :password => evaluator.password)
    end
  end
end
