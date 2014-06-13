FactoryGirl.define do
  factory :assigned_server_role do
    active          TRUE
    priority        AssignedServerRole::HIGH_PRIORITY
  end
end
