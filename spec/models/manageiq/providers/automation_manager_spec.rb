describe ManageIQ::Providers::AutomationManager do
  let(:provider)           { FactoryGirl.build(:provider) }
  let(:automation_manager) { FactoryGirl.build(:automation_manager, :provider => provider) }
end
