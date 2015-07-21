require 'spec_helper'

describe ManageIQ::Providers::Foreman::ConfigurationManager::ProvisionWorkflow do
  it "#allowed_configuration_profiles" do
    cp       = FactoryGirl.build(:configuration_profile, :name => "test profile")
    cs       = FactoryGirl.build(:configured_system_foreman)
    workflow = FactoryGirl.build(:miq_provision_configured_system_foreman_workflow)

    workflow.instance_variable_set(:@values, :src_configured_system_ids => [cs.id])
    ConfiguredSystem.should_receive(:common_configuration_profiles_for_selected_configured_systems).with([cs.id]).and_return([cp])

    expect(workflow.allowed_configuration_profiles).to eq(cp.id => cp.name)
  end
end
