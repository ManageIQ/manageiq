require "spec_helper"

describe MiqProvisionOpenstack do
  let(:options)      { {:src_vm_id => [template.id, template.name]} }
  let(:provider)     { FactoryGirl.create(:ems_openstack_with_authentication) }
  let(:template)     { FactoryGirl.create(:template_openstack, :ext_management_system => provider) }
  let(:user)         { FactoryGirl.create(:user) }
  let(:vm_openstack) { FactoryGirl.create(:vm_openstack, :ext_management_system => provider, :ems_ref => "6b586084-6c37-11e4-b299-56847afe9799") }
  let(:vm_prov)      { FactoryGirl.create(:miq_provision_openstack, :userid => user.userid, :source => template, :request_type => 'template', :state => 'pending', :status => 'Ok', :options => options) }

  before { subject.source = template }

  context "#find_destination_in_vmdb" do
    it "VM in same sub-class" do
      expect(vm_openstack).to eq(subject.find_destination_in_vmdb("6b586084-6c37-11e4-b299-56847afe9799"))
    end

    it "VM in different sub-class" do
      FactoryGirl.create(:vm_amazon, :ext_management_system => provider, :ems_ref => "6b586084-6c37-11e4-b299-56847afe9799")

      expect(subject.find_destination_in_vmdb("6b586084-6c37-11e4-b299-56847afe9799")).to be_nil
    end
  end

  context "#validate_dest_name" do
    it "with valid name" do
      subject.stub(:dest_name).and_return("new_vm_1")

      expect { subject.validate_dest_name }.to_not raise_error
    end

    it "with a nil name" do
      subject.stub(:dest_name).and_return(nil)

      expect { subject.validate_dest_name }.to raise_error(MiqException::MiqProvisionError)
    end

    it "with a duplicate name" do
      subject.stub(:dest_name).and_return(vm_openstack.name)

      expect { subject.validate_dest_name }.to raise_error(MiqException::MiqProvisionError)
    end
  end

  context "#prepare_for_clone_task" do
    let(:flavor)  { FactoryGirl.create(:flavor_openstack) }

    before { subject.stub(:instance_type => flavor, :validate_dest_name => nil) }

    context "availability zone" do
      let(:az)      { FactoryGirl.create(:availability_zone_openstack,      :ems_ref => "64890ac2-6c34-11e4-b72d-56847afe9799") }
      let(:az_null) { FactoryGirl.create(:availability_zone_openstack_null, :ems_ref => "6fd878d6-6c34-11e4-b72d-56847afe9799") }

      it "with valid Availability Zone" do
        subject.options[:dest_availability_zone] = [az.id, az.name]

        expect(subject.prepare_for_clone_task[:availability_zone]).to eq("64890ac2-6c34-11e4-b72d-56847afe9799")
      end

      it "with Null Availability Zone" do
        subject.options[:dest_availability_zone] = [az_null.id, az_null.name]

        expect(subject.prepare_for_clone_task[:availability_zone]).to be_nil
      end
    end

    context "security_groups" do
      let(:security_group_1) { FactoryGirl.create(:security_group_openstack, :ems_ref => "340c315c-6c30-11e4-a103-56847afe9799") }
      let(:security_group_2) { FactoryGirl.create(:security_group_openstack, :ems_ref => "41a73064-6c30-11e4-a103-56847afe9799") }

      it "with no security groups" do
        expect(subject.prepare_for_clone_task[:security_groups]).to eq([])
      end

      it "with one security group" do
        subject.options[:security_groups] = [security_group_1.id]

        expect(subject.prepare_for_clone_task[:security_groups]).to eq([security_group_1.ems_ref])
      end

      it "with two security group" do
        subject.options[:security_groups] = [security_group_1.id, security_group_2.id]

        expect(subject.prepare_for_clone_task[:security_groups]).to eq([security_group_1.ems_ref, security_group_2.ems_ref])
      end

      it "with a missing security group" do
        subject.options[:security_groups] = [security_group_1.id, (security_group_1.id + 1)]

        expect(subject.prepare_for_clone_task[:security_groups]).to eq([security_group_1.ems_ref])
      end
    end
  end

  it "#workflow" do
    MiqProvisionWorkflow.any_instance.stub(:get_dialogs => {:dialogs => {}})

    expect(vm_prov.workflow).to be_kind_of(MiqProvisionOpenstackWorkflow)
  end
end
