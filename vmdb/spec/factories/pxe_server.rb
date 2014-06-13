FactoryGirl.define do
  factory :pxe_server do
    sequence(:name) { |n| "pxe_server_#{n}" }
    sequence(:uri)  { |n| "http://test.example.com/pxe_server_#{n}" }
  end
end
