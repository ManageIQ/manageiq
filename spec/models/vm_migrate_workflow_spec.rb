RSpec.describe VmMigrateWorkflow do
  include Spec::Support::WorkflowHelper
  let(:admin) { FactoryBot.create(:user_with_group) }
  let(:ems) { FactoryBot.create(:ems_vmware) }
  let(:vm) { FactoryBot.create(:vm_vmware, :name => 'My VM', :ext_management_system => ems) }

  let(:redhat_ems) { FactoryBot.create(:ems_redhat) }
  let(:redhat_vm) { FactoryBot.create(:vm_redhat, :name => 'My RHV VM', :ext_management_system => redhat_ems) }

  context "With a Valid Template," do
    context "#allowed_hosts" do
      let(:workflow) { VmMigrateWorkflow.new({:src_ids => [vm.id]}, admin) }

      context "#allowed_hosts" do
        it "with no hosts" do
          stub_dialog
          expect(workflow.allowed_hosts).to eq([])
        end

        it "with a host" do
          stub_dialog
          host = FactoryBot.create(:host_vmware, :ext_management_system => ems)
          host.set_parent(ems)
          allow(workflow).to receive(:process_filter).and_return([host])

          expect(workflow.allowed_hosts).to eq([workflow.ci_to_hash_struct(host)])
        end
      end
    end
  end

  describe "Configuring targets" do
    context "redhat VM" do
      let(:workflow) { VmMigrateWorkflow.new({:src_ids => [redhat_vm.id]}, admin) }

      it "excludes some properties in" do
        stub_dialog
        workflow.get_source_and_targets
        target_resource = workflow.instance_variable_get(:@target_resource)
        expect(target_resource).not_to include(:storage_id, :respool_id, :folder_id,
                                               :datacenter_id, :cluster_id)
        expect(target_resource).to include(:host_id)
      end
    end

    context "vmware VM" do
      let(:workflow) { VmMigrateWorkflow.new({:src_ids => [vm.id]}, admin) }

      it "includes all properties in" do
        stub_dialog
        workflow.get_source_and_targets
        target_resource = workflow.instance_variable_get(:@target_resource)
        expect(target_resource).to include(:host_id, :cluster_id, :storage_id, :respool_id,
                                           :folder_id, :datacenter_id)
      end
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryBot.create(:user_with_group) }

    it "creates and update a request" do
      EvmSpecHelper.local_miq_server
      stub_dialog

      # if running_pre_dialog is set, it will run 'continue_request'
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_migrate_request_created",
        :target_class => "Vm",
        :userid       => admin.userid,
        :message      => "VM Migrate requested by <#{admin.userid}> for Vm:#{[vm.id].inspect}"
      )

      # creates a request

      # the dialogs populate this
      values.merge!(:src_ids => [vm.id], :vm_tags => [])

      request = workflow.make_request(nil, values)

      expect(request).to be_valid
      expect(request).to be_a_kind_of(VmMigrateRequest)
      expect(request.request_type).to eq("vm_migrate")
      expect(request.description).to eq("VM Migrate for: #{vm.name} - ")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)
      expect(request.workflow).to be_a described_class

      # updates a request

      workflow = described_class.new(values, alt_user)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_migrate_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Migrate request updated by <#{alt_user.userid}> for Vm:#{[vm.id].inspect}"
      )
      workflow.make_request(request, values)
    end
  end
end
