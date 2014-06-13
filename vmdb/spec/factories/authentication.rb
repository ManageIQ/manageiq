FactoryGirl.define do
  factory :authentication do
    userid      "testuser"
    password    "secret"
    authtype    "default"
  end

  factory :authentication_ipmi, :parent => :authentication do
    authtype    "ipmi"
  end

end
