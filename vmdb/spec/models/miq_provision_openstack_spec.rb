require "spec_helper"

describe MiqProvisionOpenstack do
  let(:provider) { FactoryGirl.create(:ems_openstack_with_authentication) }
  let(:template) { FactoryGirl.create(:template_openstack, :ext_management_system => provider) }

  before(:each) do
    subject.source = template
  end

  context "#find_destination_in_vmdb" do
    it "VM in same sub-class" do
      vm = FactoryGirl.create(:vm_openstack, :ext_management_system => provider, :ems_ref => "vm_1")
      subject.find_destination_in_vmdb("vm_1").should == vm
    end

    it "VM in different sub-class" do
      vm = FactoryGirl.create(:vm_amazon, :ext_management_system => provider, :ems_ref => "vm_1")
      subject.find_destination_in_vmdb("vm_1").should be_nil
    end
  end

  context "#validate_dest_name" do
    let(:vm) { FactoryGirl.create(:vm_openstack, :ext_management_system => provider) }

    it "with valid name" do
      subject.stub(:dest_name).and_return("new_vm_1")
      expect { subject.validate_dest_name }.to_not raise_error
    end

    it "with a black name" do
      subject.stub(:dest_name).and_return("")
      expect { subject.validate_dest_name }.to raise_error
    end

    it "with a nil name" do
      subject.stub(:dest_name).and_return(nil)
      expect { subject.validate_dest_name }.to raise_error
    end

    it "with a duplicate name" do
      subject.stub(:dest_name).and_return(vm.name)
      expect { subject.validate_dest_name }.to raise_error
    end
  end

  context "#prepare_for_clone_task" do
    before do
      subject.should_receive(:validate_dest_name)
      subject.stub(:source).and_return(template)
      flavor = FactoryGirl.create(:flavor_openstack)
      subject.stub(:instance_type).and_return(flavor)
    end

    context "availability zone" do
      it "with valid Availability Zone" do
        az = FactoryGirl.create(:availability_zone_openstack, :ems_ref => "test_ref")
        subject.options[:dest_availability_zone] = [az.id, az.name]
        subject.prepare_for_clone_task[:availability_zone].should == "test_ref"
      end

      it "with Null Availability Zone" do
        az = FactoryGirl.create(:availability_zone_openstack_null, :ems_ref => "null_az")
        subject.options[:dest_availability_zone] = [az.id, az.name]
        subject.prepare_for_clone_task[:availability_zone].should be_nil
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
    user    = FactoryGirl.create(:user)
    options = {:src_vm_id => [template.id, template.name]}
    vm_prov = FactoryGirl.create(:miq_provision_openstack,
                                 :userid       => user.userid,
                                 :source       => template,
                                 :request_type => 'template',
                                 :state        => 'pending',
                                 :status       => 'Ok',
                                 :options      => options)
    MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})

    vm_prov.workflow.class.should eq MiqProvisionOpenstackWorkflow
  end

end
