FactoryGirl.define do
  factory :authentication do
    type        "AuthUseridPassword"
    userid      "testuser"
    password    "secret"
    authtype    "default"
  end

  factory :authentication_ipmi, :parent => :authentication do
    authtype    "ipmi"
  end

end
