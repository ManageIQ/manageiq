FactoryGirl.define do
  factory :miq_dialog do
    sequence(:name)        { |n| "miq_dialog_#{n}" }
    sequence(:description) { |n| "MiqDialog #{n}" }
    content                { {:dialogs => {}} }
  end

  factory :miq_dialog_provision, :parent => :miq_dialog do
    name        "miq_provision_dialogs"
    dialog_type "MiqProvisionWorkflow"

    content do
      {
        :dialogs => {
          :customize => {
            :description => "Customize",
            :fields      => {
              :root_password => {
                :description => "Root Password",
                :required    => false,
                :display     => :edit,
                :data_type   => :string
              }
            }
          }
        }
      }
    end
  end

  factory :miq_dialog_host_provision, :parent => :miq_dialog do
    name        "miq_host_provision_dialogs"
    dialog_type "MiqHostProvisionWorkflow"
  end

  factory :miq_provision_configured_system_foreman_dialog, :parent => :miq_dialog do
    name        "miq_provision_configured_system_foreman_dialogs"
    dialog_type "MiqProvisionConfiguredSystemWorkflow"
  end

  factory :miq_dialog_aws_provision, :parent => :miq_dialog do
    name        "miq_provision_amazon_dialogs_template"
    dialog_type "MiqProvisionWorkflow"

    content do
      path = Rails.root.join("product", "dialogs", "miq_dialogs", "miq_provision_amazon_dialogs_template.yaml")
      YAML.load_file(path)[:content]
    end
  end
end
