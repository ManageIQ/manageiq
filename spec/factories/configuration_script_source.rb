FactoryBot.define do
  factory :configuration_script_source do
    sequence(:name) { |n| "configuration_script_source#{seq_padded_for_sorting(n)}" }
  end

  factory :ansible_configuration_script_source,
          :parent => :configuration_script_source,
          :class  => "ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource"

  factory :embedded_ansible_configuration_script_source,
          :parent => :configuration_script_source,
          :class  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource" do
    scm_url { "https://example.com/foo.git" }
  end
end
