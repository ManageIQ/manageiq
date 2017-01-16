FactoryGirl.define do
  factory :configuration_script_base do
    sequence(:name) { |n| "Configuration_script_base_#{seq_padded_for_sorting(n)}" }
    sequence(:manager_ref) { SecureRandom.random_number(100) }
    variables :instance_ids => ['i-3434']
  end

  factory :configuration_script_payload, :class => "ConfigurationScriptPayload", :parent => :configuration_script_base
  factory :ansible_playbook,
          :class => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::Playbook",
          :parent => :configuration_script_payload

  factory :configuration_script, :class => "ConfigurationScript", :parent => :configuration_script_base
  factory :ansible_configuration_script,
          :class => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript",
          :parent => :configuration_script
end
