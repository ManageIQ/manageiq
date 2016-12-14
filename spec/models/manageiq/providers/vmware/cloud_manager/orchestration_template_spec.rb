describe ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate do
  describe ".eligible_manager_types" do
    it "lists the classes of eligible managers" do
      ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate.eligible_manager_types.each do |klass|
        expect(klass <= ManageIQ::Providers::Vmware::CloudManager).to be_truthy
      end
    end
  end

  let(:valid_template) { FactoryGirl.create(:orchestration_template_vmware_cloud_with_content) }

  describe '#validate_format' do
    it 'passes validation if no content' do
      template = ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate.new
      expect(template.validate_format).to be_nil
    end

    it 'passes validation with correct OVF content' do
      expect(valid_template.validate_format).to be_nil
    end

    it 'fails validations with incorrect OVF content' do
      template = ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate.new(:content => "Invalid String")
      expect(template.validate_format).not_to be_nil
    end
  end

  describe "OVF content of vApp template" do
    let(:vdc_net1) { FactoryGirl.create(:cloud_network_vmware_vdc, :name => "VDC1", :ems_ref => "vdc_net1") }
    let(:vapp_net) { FactoryGirl.create(:cloud_network_vmware_vapp, :name => "vapp", :ems_ref => "vapp") }
    let(:ems) do
      FactoryGirl.create(:ems_vmware_cloud) do |ems|
        ems.cloud_networks << vdc_net1
        ems.cloud_networks << vapp_net
      end
    end
    let(:orchestration_template) { FactoryGirl.create(:orchestration_template_vmware_cloud_with_content, :ems_id => ems.id) }

    context "orchestration template OVF file" do
      it "is properly read" do
        expect(orchestration_template.content.include?('ovf:Envelope')).to be_truthy
      end

      it "is parsed using MiqXml" do
        ovf_doc = MiqXml.load(orchestration_template.content)

        expect(ovf_doc).not_to be(nil)
        expect(ovf_doc.root.name).not_to be("Envelope")
      end
    end

    context "orchestration template" do
      it "creates parameter groups for the given template" do
        parameter_groups = orchestration_template.parameter_groups

        expect(parameter_groups.size).to eq(3)

        assert_vapp_parameter_group(parameter_groups[0])
        assert_vm_parameter_group(parameter_groups[1], "VM1", "e9b55b85-640b-462c-9e7a-d18c47a7a5f3")
        assert_vm_parameter_group(parameter_groups[2], "VM2", "04f85cca-3f8d-43b4-8473-7aa099f95c1b")
      end
    end
  end

  def assert_vapp_parameter_group(group)
    expect(group.parameters.size).to eq(2)

    expect(group.parameters[0]).to have_attributes(
      :name          => "deploy",
      :label         => "Deploy vApp",
      :data_type     => "boolean",
      :default_value => true,
    )
    expect(group.parameters[0].constraints.size).to be(1)
    expect(group.parameters[0].constraints[0]).to be_instance_of(OrchestrationTemplate::OrchestrationParameterBoolean)
    expect(group.parameters[1]).to have_attributes(
      :name          => "powerOn",
      :label         => "Power On vApp",
      :data_type     => "boolean",
      :default_value => false,
    )
    expect(group.parameters[1].constraints.size).to be(1)
    expect(group.parameters[1].constraints[0]).to be_instance_of(OrchestrationTemplate::OrchestrationParameterBoolean)
  end

  def assert_vm_parameter_group(group, vm_name, vm_id)
    expect(group.parameters.size).to eq(2)

    assert_parameter(group.parameters[0],
                     :name          => "instance_name-#{vm_id}",
                     :label         => "Instance name",
                     :data_type     => "string",
                     :default_value => vm_name)

    assert_parameter(group.parameters[1],
                     :name          => "vdc_network-#{vm_id}",
                     :label         => "Network",
                     :data_type     => "string",
                     :default_value => "(default)")

    network_parameter = group.parameters[1]
    expect(network_parameter.constraints.count).to eq(1)
    expect(network_parameter.constraints[0].fqname).to eq("/Cloud/Orchestration/Operations/Methods/Available_Vdc_Networks")
  end

  def assert_parameter(field, attributes)
    expect(field).to have_attributes(attributes)
  end
end
