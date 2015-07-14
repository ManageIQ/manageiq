require "spec_helper"

describe EmsInfra do
  it ".types" do
    expected_types = [ManageIQ::Providers::Vmware::InfraManager, ManageIQ::Providers::Redhat::InfraManager, EmsMicrosoft, EmsOpenstackInfra].collect(&:ems_type)
    described_class.types.should match_array(expected_types)
  end

  it ".supported_subclasses" do
    expected_subclasses = [ManageIQ::Providers::Vmware::InfraManager, EmsMicrosoft, ManageIQ::Providers::Redhat::InfraManager, EmsOpenstackInfra]
    described_class.supported_subclasses.should match_array(expected_subclasses)
  end

  it ".supported_types" do
    expected_types = [ManageIQ::Providers::Vmware::InfraManager, EmsMicrosoft, ManageIQ::Providers::Redhat::InfraManager, EmsOpenstackInfra].collect(&:ems_type)
    described_class.supported_types.should match_array(expected_types)
  end

end
