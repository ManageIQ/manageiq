require_relative '../aws_helper'

describe ManageIQ::Providers::Amazon::CloudManager::Provision do
  let(:provider) { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:template) { FactoryGirl.create(:template_amazon, :ext_management_system => provider, :ems_ref => 'id-123') }

  before(:each) do
    subject.source = template
  end

  context "Cloning" do
    describe "#find_destination_in_vmdb" do
      it "finds VM in same sub-class" do
        vm = FactoryGirl.create(:vm_amazon, :ext_management_system => provider, :ems_ref => "vm_1")
        expect(subject.find_destination_in_vmdb("vm_1")).to eq(vm)
      end

      it "does not find VM in different sub-class" do
        FactoryGirl.create(:vm_openstack, :ext_management_system => provider, :ems_ref => "vm_1")
        expect(subject.find_destination_in_vmdb("vm_1")).to be_nil
      end
    end

    describe "#prepare_for_clone_task" do
      before do
        flavor            = FactoryGirl.create(:flavor_amazon)
        availability_zone = FactoryGirl.create(:availability_zone_amazon)
        allow(subject).to receive(:source).and_return(template)
        allow(subject).to receive(:instance_type).and_return(flavor)
        allow(subject).to receive(:dest_availability_zone).and_return(availability_zone)
        allow(subject).to receive(:validate_dest_name)
      end

      it "calls super" do
        # can't test call to super, but we know :validate_dest_name is called in super
        expect(subject).to receive(:validate_dest_name)
        subject.prepare_for_clone_task
      end

      context "with security_groups" do
        it "with no security groups" do
          expect(subject.prepare_for_clone_task[:security_group_ids]).to be_nil
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

    describe "#workflow_class" do
      it "returns the correct class" do
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

        expect(vm_prov.workflow_class).to eq workflow_class
      end
    end

    describe "#start_clone" do
      it "starts an instance" do
        flavor = FactoryGirl.create(:flavor_amazon)
        allow(subject).to receive(:source).and_return(template)
        allow(subject).to receive(:instance_type).and_return(flavor)
        allow(subject).to receive(:dest_name).and_return(template.ems_ref)

        stubbed_aws = {
          :run_instances => {
            :instances => [{:instance_id => template.ems_ref}]
          }
        }
        with_aws_stubbed(:ec2 => stubbed_aws) do
          clone_options = subject.prepare_for_clone_task
          expect(subject.start_clone(clone_options)).to eq(template.ems_ref)
        end
      end
    end
  end
end
