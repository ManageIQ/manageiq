require "spec_helper"

describe ManageIQ::Providers::Azure::CloudManager::Provision do
  let(:provider)  { FactoryGirl.create(:ems_azure_with_authentication) }
  let(:template)  { FactoryGirl.create(:template_azure, :ext_management_system => provider) }
  let(:flavor)    { FactoryGirl.create(:flavor_azure) }
  let(:vm)        { FactoryGirl.create(:vm_azure, :ext_management_system => provider) }
  let(:sec_group) { FactoryGirl.create(:security_group_azure) }
  let(:subnet)    { FactoryGirl.create(:cloud_subnet_azure) }

  context "#create vm" do
    subscription_id = "01234567890"
    resource_group  = "test_resource_group"
    type            = "microsoft.resources"
    name            = "vm_1"
    nic_id          = "nic_id_1"

    before do
      subject.source = template
      allow(subject).to receive(:gather_storage_account_properties).and_return(%w("target_uri", "source_uri", "windows"))
      allow(subject).to receive(:create_nic).and_return(nic_id)
    end

    context "#find_destination_in_vmdb" do
      vm_uid_hash = {
        :subscription_id => subscription_id,
        :resource_group  => resource_group,
        :type            => type,
        :name            => name
      }
      it "VM in same sub-class" do
        vm_uid_hash[:subscription_id] = subscription_id
        vm
        expect(subject.find_destination_in_vmdb(vm_uid_hash)).to eq(vm)
      end

      it "VM in same sub-class with invalid parameters" do
        vm_uid_hash[:subscription_id] = "invalid_subscription_id"
        expect(subject.find_destination_in_vmdb(vm_uid_hash)).to be_nil
      end

      it "VM in different sub-class" do
        vm = FactoryGirl.create(:vm_openstack, :ext_management_system => provider)
        expect(subject.find_destination_in_vmdb(:ems_ref => vm.ems_ref)).to be_nil
      end
    end

    context "#validate_dest_name" do
      let(:vm) { FactoryGirl.create(:vm_azure, :ext_management_system => provider) }

      it "with valid name" do
        allow(subject).to receive(:dest_name).and_return("new_vm_1")
        expect { subject.validate_dest_name }.to_not raise_error
      end

      it "with a blank name" do
        allow(subject).to receive(:dest_name).and_return("")
        expect { subject.validate_dest_name }
          .to raise_error(MiqException::MiqProvisionError, /Name cannot be blank/)
      end

      it "with a nil name" do
        allow(subject).to receive(:dest_name).and_return(nil)
        expect { subject.validate_dest_name }
          .to raise_error(MiqException::MiqProvisionError, /Name cannot be blank/)
      end

      it "with a duplicate name" do
        allow(subject).to receive(:dest_name).and_return(vm.name)
        expect { subject.validate_dest_name }
          .to raise_error(MiqException::MiqProvisionError, /already exists/)
      end
    end

    context "#prepare_for_clone_task" do
      before do
        allow(subject).to receive(:instance_type).and_return(flavor)
        allow(subject).to receive(:dest_name).and_return(vm.name)
        allow(subject).to receive(:cloud_subnet).and_return(subnet)
      end

      context "nic settings" do
        it "with nic" do
          subject.options[:vm_target_name] = name
          expect(subject.prepare_for_clone_task[:properties][:networkProfile][:networkInterfaces][0][:id]).to eq(nic_id)
        end
      end

      context "security group" do
        it "with security group" do
          allow(subject).to receive(:security_group).and_return(sec_group)
          expect(subject.build_nic_options("ip")[:properties][:networkSecurityGroup][:id]).to eq(sec_group.ems_ref)
        end

        it "without security group" do
          allow(subject).to receive(:security_group).and_return(nil)
          expect(subject.build_nic_options("ip")[:properties]).not_to have_key(:networkSecurityGroup)
        end
      end
    end

    it "#workflow" do
      user    = FactoryGirl.create(:user)
      options = {:src_vm_id => [template.id, template.name]}
      vm_prov = FactoryGirl.create(:miq_provision_azure,
                                   :userid       => user.userid,
                                   :source       => template,
                                   :request_type => 'template',
                                   :state        => 'pending',
                                   :status       => 'Ok',
                                   :options      => options)

      workflow_class = ManageIQ::Providers::Azure::CloudManager::ProvisionWorkflow
      allow_any_instance_of(workflow_class).to receive(:get_dialogs).and_return(:dialogs => {})

      expect(vm_prov.workflow.class).to eq workflow_class
      expect(vm_prov.workflow_class).to eq workflow_class
    end
  end
end
