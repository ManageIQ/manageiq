require "spec_helper"

describe VmMigrateWorkflow do
  include WorkflowSpecHelper
  let(:admin) { FactoryGirl.create(:user_with_group) }
  let(:ems) { FactoryGirl.create(:ems_vmware) }
  let(:vm) { FactoryGirl.create(:vm_vmware, :name => 'My VM', :ext_management_system => ems) }

  context "With a Valid Template," do
    context "#allowed_hosts" do
      let(:workflow) { VmMigrateWorkflow.new({:src_ids => [vm.id]}, admin.userid) }

      context "#allowed_hosts" do
        it "with no hosts" do
          stub_dialog
          workflow.allowed_hosts.should == []
        end

        it "with a host" do
          stub_dialog
          host = FactoryGirl.create(:host_vmware, :ext_management_system => ems)
          host.set_parent(ems)
          workflow.stub(:process_filter).and_return([host])

          workflow.allowed_hosts.should == [workflow.ci_to_hash_struct(host)]
        end
      end
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryGirl.create(:user_with_group) }

    it "creates and update a request" do
      EvmSpecHelper.local_miq_server
      stub_dialog

      # if running_pre_dialog is set, it will run 'continue_request'
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_migrate_request_created",
        :target_class => "Vm",
        :userid       => admin.userid,
        :message      => "VM Migrate requested by <#{admin.userid}> for Vm:#{[vm.id].inspect}"
      )

      # creates a request

      # the dialogs populate this
      values.merge!(:src_ids => [vm.id], :vm_tags => [])

      request = workflow.make_request(nil, values, admin.userid) # TODO: nil

      expect(request).to be_valid
      expect(request).to be_a_kind_of(VmMigrateRequest)
      expect(request.request_type).to eq("vm_migrate")
      expect(request.description).to eq("VM Migrate for: #{vm.name} - ")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      workflow = described_class.new(values, alt_user.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_migrate_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Migrate request updated by <#{alt_user.userid}> for Vm:#{[vm.id].inspect}"
      )
      workflow.make_request(request, values, alt_user.userid)
    end
  end
end
