describe ManageIQ::Providers::Amazon::CloudManager::Provision do
  let(:provider) { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:template) { FactoryGirl.create(:template_amazon, :ext_management_system => provider) }

  before(:each) do
    subject.source = template
  end

  context "#find_destination_in_vmdb" do
    it "VM in same sub-class" do
      vm = FactoryGirl.create(:vm_amazon, :ext_management_system => provider, :ems_ref => "vm_1")
      expect(subject.find_destination_in_vmdb("vm_1")).to eq(vm)
    end

    it "VM in different sub-class" do
      vm = FactoryGirl.create(:vm_openstack, :ext_management_system => provider, :ems_ref => "vm_1")
      expect(subject.find_destination_in_vmdb("vm_1")).to be_nil
    end
  end

  context "#validate_dest_name" do
    let(:vm) { FactoryGirl.create(:vm_amazon, :ext_management_system => provider) }

    it "with valid name" do
      allow(subject).to receive(:dest_name).and_return("new_vm_1")
      expect { subject.validate_dest_name }.to_not raise_error
    end

    it "with a blank name" do
      allow(subject).to receive(:dest_name).and_return("")
      expect { subject.validate_dest_name }
        .to raise_error(MiqException::MiqProvisionError, /Destination Name cannot be blank/)
    end

    it "with a nil name" do
      allow(subject).to receive(:dest_name).and_return(nil)
      expect { subject.validate_dest_name }
        .to raise_error(MiqException::MiqProvisionError, /Destination Name cannot be blank/)
    end

    it "with a duplicate name" do
      allow(subject).to receive(:dest_name).and_return(vm.name)
      expect { subject.validate_dest_name }.to raise_error(MiqException::MiqProvisionError, /already exists/)
    end
  end

  context "#prepare_for_clone_task" do
    before do
      flavor            = FactoryGirl.create(:flavor_amazon)
      availability_zone = FactoryGirl.create(:availability_zone_amazon)
      allow(subject).to receive(:source).and_return(template)
      allow(subject).to receive(:instance_type).and_return(flavor)
      allow(subject).to receive(:dest_availability_zone).and_return(availability_zone)
      expect(subject).to receive(:validate_dest_name)
    end

    context "security_groups" do
      it "with no security groups" do
        expect(subject.prepare_for_clone_task[:security_group_ids]).to eq([])
      end

      it "with one security group" do
        security_group = FactoryGirl.create(:security_group_amazon, :name => "group_1")
        subject.options[:security_groups] = [security_group.id]
        expect(subject.prepare_for_clone_task[:security_group_ids]).to eq([security_group.ems_ref])
      end

      it "with two security group" do
        security_group_1 = FactoryGirl.create(:security_group_amazon, :name => "group_1")
        security_group_2 = FactoryGirl.create(:security_group_amazon, :name => "group_2")
        subject.options[:security_groups] = [security_group_1.id, security_group_2.id]
        expect(subject.prepare_for_clone_task[:security_group_ids])
          .to match_array([security_group_1.ems_ref, security_group_2.ems_ref])
      end

      it "with a missing security group" do
        security_group = FactoryGirl.create(:security_group_amazon, :name => "group_1")
        bad_security_group_id = security_group.id + 1
        subject.options[:security_groups] = [security_group.id, bad_security_group_id]
        expect(subject.prepare_for_clone_task[:security_group_ids]).to eq([security_group.ems_ref])
      end
    end

    context "cloud_subnet" do
      it "without a subnet" do
        expect(subject.prepare_for_clone_task[:subnet]).to be_nil
      end

      it "with a subnet" do
        cloud_subnet = FactoryGirl.create(:cloud_subnet)
        subject.options[:cloud_subnet] = [cloud_subnet.id, cloud_subnet.name]
        expect(subject.prepare_for_clone_task[:subnet_id]).to eq(cloud_subnet.ems_ref)
      end
    end
  end

  it "#workflow" do
    user    = FactoryGirl.create(:user)
    options = {:src_vm_id => [template.id, template.name]}
    vm_prov = FactoryGirl.create(:miq_provision_amazon,
                                 :userid       => user.userid,
                                 :source       => template,
                                 :request_type => 'template',
                                 :state        => 'pending',
                                 :status       => 'Ok',
                                 :options      => options)

    workflow_class = ManageIQ::Providers::Amazon::CloudManager::ProvisionWorkflow
    allow_any_instance_of(workflow_class).to receive(:get_dialogs).and_return(:dialogs => {})

    expect(vm_prov.workflow.class).to eq workflow_class
    expect(vm_prov.workflow_class).to eq workflow_class
  end
end
