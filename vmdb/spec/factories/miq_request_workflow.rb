FactoryGirl.define do
  factory :miq_request_workflow do
    skip_create
    initialize_with { new({:provision_dialog_name => "miq_provision_dialogs"}, "admin") }
  end
end
