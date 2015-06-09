require "spec_helper"

describe MiqProvisionAmazon do
  let(:provider) { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:template) { FactoryGirl.create(:template_amazon, :ext_management_system => provider) }

  before(:each) do
    subject.source = template
  end

  context "#find_destination_in_vmdb" do
    it "VM in same sub-class" do
      vm = FactoryGirl.create(:vm_amazon, :ext_management_system => provider, :ems_ref => "vm_1")
      subject.find_destination_in_vmdb("vm_1").should == vm
    end

    it "VM in different sub-class" do
      vm = FactoryGirl.create(:vm_openstack, :ext_management_system => provider, :ems_ref => "vm_1")
      subject.find_destination_in_vmdb("vm_1").should be_nil
    end
  end

  context "#validate_dest_name" do
    let(:vm) { FactoryGirl.create(:vm_amazon, :ext_management_system => provider) }

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
      flavor            = FactoryGirl.create(:flavor_amazon)
      availability_zone = FactoryGirl.create(:availability_zone_amazon)
      subject.stub(:source).and_return(template)
      subject.stub(:instance_type).and_return(flavor)
      subject.stub(:dest_availability_zone).and_return(availability_zone)
      subject.should_receive(:validate_dest_name)
    end

    context "security_groups" do
      it "with no security groups" do
        subject.prepare_for_clone_task[:security_group_ids].should == []
      end

      it "with one security group" do
        security_group = FactoryGirl.create(:security_group_amazon, :name => "group_1")
        subject.options[:security_groups] = [security_group.id]
        subject.prepare_for_clone_task[:security_group_ids].should == [security_group.ems_ref]
      end

      it "with two security group" do
        security_group_1 = FactoryGirl.create(:security_group_amazon, :name => "group_1")
        security_group_2 = FactoryGirl.create(:security_group_amazon, :name => "group_2")
        subject.options[:security_groups] = [security_group_1.id, security_group_2.id]
        subject.prepare_for_clone_task[:security_group_ids].should match_array([security_group_1.ems_ref, security_group_2.ems_ref])
      end

      it "with a missing security group" do
        security_group = FactoryGirl.create(:security_group_amazon, :name => "group_1")
        bad_security_group_id = security_group.id + 1
        subject.options[:security_groups] = [security_group.id, bad_security_group_id]
        subject.prepare_for_clone_task[:security_group_ids].should == [security_group.ems_ref]
      end
    end

    context "cloud_subnet" do
      it "without a subnet" do
        subject.prepare_for_clone_task[:subnet].should be_nil
      end

      it "with a subnet" do
        cloud_subnet = FactoryGirl.create(:cloud_subnet)
        subject.options[:cloud_subnet] = [cloud_subnet.id, cloud_subnet.name]
        subject.prepare_for_clone_task[:subnet].should == cloud_subnet.ems_ref
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
    MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})

    vm_prov.workflow.class.should eq MiqProvisionAmazonWorkflow
  end
end
