RSpec.describe MiqProvisionOrchWorkflow do
  let(:workflow) { FactoryBot.create(:miq_provision_orch_workflow) }
  let(:orch_template) { FactoryBot.create(:orchestration_template) }

  context "#new" do
    let(:user) { FactoryBot.create(:user_with_email) }

    it "calls OrchestrationTemplate" do
      expect(OrchestrationTemplate).to receive(:find_by).with(:id => orch_template.id).once
      MiqProvisionOrchWorkflow.new({:src_vm_id => [orch_template.id]}, user, :skip_dialog_load => true, :initial_pass => true)
    end
  end
end
