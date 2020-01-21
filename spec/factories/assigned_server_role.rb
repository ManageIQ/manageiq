FactoryBot.define do
  factory :assigned_server_role do
    active          { true }
    priority        { AssignedServerRole::HIGH_PRIORITY }
  end

  factory :assigned_server_role_in_master_region, :parent => :assigned_server_role do
    # GOAL: master_supported? = true, regional_role? = true
    server_role { FactoryBot.create(:server_role, :role_scope => "region", :max_concurrent => 1) }
  end
end
