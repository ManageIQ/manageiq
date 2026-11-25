RSpec.describe ManageIQ::Providers::HpcManager do
  let(:ems) { FactoryBot.create(:ems_hpc) }

  describe "associations" do
    let!(:active_queue)   { FactoryBot.create(:hpc_queue, :ext_management_system => ems) }
    let!(:archived_queue) { FactoryBot.create(:hpc_queue, :ext_management_system => ems, :deleted_on => Time.now.utc) }
    let!(:active_node)    { FactoryBot.create(:hpc_node, :ext_management_system => ems) }
    let!(:archived_node)  { FactoryBot.create(:hpc_node, :ext_management_system => ems, :deleted_on => Time.now.utc) }
    let!(:active_job)     { FactoryBot.create(:hpc_job, :ext_management_system => ems, :hpc_queue => active_queue) }
    let!(:archived_job)   { FactoryBot.create(:hpc_job, :ext_management_system => ems, :hpc_queue => active_queue, :deleted_on => Time.now.utc) }

    it "active associations exclude archived rows" do
      expect(ems.hpc_queues).to contain_exactly(active_queue)
      expect(ems.hpc_nodes).to contain_exactly(active_node)
      expect(ems.hpc_jobs).to contain_exactly(active_job)
    end

    it "all_ associations include both active and archived rows" do
      expect(ems.all_hpc_queues).to contain_exactly(active_queue, archived_queue)
      expect(ems.all_hpc_nodes).to contain_exactly(active_node, archived_node)
      expect(ems.all_hpc_jobs).to contain_exactly(active_job, archived_job)
    end

    it "destroying the manager destroys all active and archived entities" do
      ems.destroy
      expect(HpcQueue.count).to eq(0)
      expect(HpcNode.count).to eq(0)
      expect(HpcJob.count).to eq(0)
    end
  end
end
