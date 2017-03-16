FactoryGirl.define do
  factory :configuration_script_source do
    sequence(:name) { |n| "configuration_script_source#{seq_padded_for_sorting(n)}" }
  end

  factory :ansible_configuration_script_source,
          :parent => :configuration_script_source,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource"
end
