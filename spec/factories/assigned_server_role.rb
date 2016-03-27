FactoryGirl.define do
  factory :assigned_server_role do
    active          { true }
    priority        { AssignedServerRole::HIGH_PRIORITY }
  end
end
