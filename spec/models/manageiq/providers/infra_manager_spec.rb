require "spec_helper"

describe EmsInfra do
  it ".types" do
    expected_types = [ManageIQ::Providers::Vmware::InfraManager, ManageIQ::Providers::Redhat::InfraManager, ManageIQ::Providers::Microsoft::InfraManager, ManageIQ::Providers::Openstack::InfraManager].collect(&:ems_type)
    described_class.types.should match_array(expected_types)
  end

  it ".supported_subclasses" do
    expected_subclasses = [ManageIQ::Providers::Vmware::InfraManager, ManageIQ::Providers::Microsoft::InfraManager, ManageIQ::Providers::Redhat::InfraManager, ManageIQ::Providers::Openstack::InfraManager]
    described_class.supported_subclasses.should match_array(expected_subclasses)
  end

  it ".supported_types" do
    expected_types = [ManageIQ::Providers::Vmware::InfraManager, ManageIQ::Providers::Microsoft::InfraManager, ManageIQ::Providers::Redhat::InfraManager, ManageIQ::Providers::Openstack::InfraManager].collect(&:ems_type)
    described_class.supported_types.should match_array(expected_types)
  end
end
