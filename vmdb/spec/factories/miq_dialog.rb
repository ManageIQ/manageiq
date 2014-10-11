FactoryGirl.define do
  factory :miq_dialog do
    sequence(:name)        { |n| "miq_dialog_#{n}" }
    sequence(:description) { |n| "MiqDialog #{n}" }
    content                { {:dialogs => {}} }
  end

  factory :miq_dialog_provision, :parent => :miq_dialog do
    name        "miq_provision_dialogs"
    dialog_type "MiqProvisionWorkflow"
  end
end
