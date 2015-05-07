FactoryGirl.define do
  factory :miq_request_workflow do
    skip_create
    initialize_with { new({:provision_dialog_name => "miq_provision_dialogs"}, "admin") }
  end

  factory :miq_provision_configured_system_foreman_workflow, :parent => :miq_request_workflow, :class => MiqProvisionConfiguredSystemForemanWorkflow do
    initialize_with do
      new({:provision_dialog_name => FactoryGirl.create(:miq_provision_configured_system_foreman_dialog).name}, FactoryGirl.create(:user_admin).userid)
    end
  end
end
