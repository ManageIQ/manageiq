FactoryGirl.define do
  factory :container_node do
    after(:create) do |x|
      x.computer_system = FactoryGirl.create(:computer_system)
    end
  end
end
