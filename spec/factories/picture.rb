FactoryGirl.define do
  factory :picture do
    extension 'png'
    after(:build) do |x|
      x.content = 'foo'
    end
  end
end
