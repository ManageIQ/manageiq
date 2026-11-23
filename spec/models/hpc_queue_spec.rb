RSpec.describe HpcQueue do
  let(:ems) { FactoryBot.create(:ems_hpc) }
  subject { FactoryBot.create(:hpc_queue, :ext_management_system => ems) }

  describe "associations" do
    it "belongs to ext_management_system" do
      expect(subject.ext_management_system).to eq(ems)
    end

    it "has many hpc_nodes through hpc_queue_nodes" do
      node1 = FactoryBot.create(:hpc_node, :ext_management_system => ems)
      node2 = FactoryBot.create(:hpc_node, :ext_management_system => ems)
      subject.hpc_nodes << [node1, node2]

      expect(subject.hpc_nodes).to contain_exactly(node1, node2)
      expect(node1.hpc_queues).to contain_exactly(subject)
    end

    it "has many hpc_jobs (active) and all_hpc_jobs" do
      active_job   = FactoryBot.create(:hpc_job, :ext_management_system => ems, :hpc_queue => subject)
      archived_job = FactoryBot.create(:hpc_job, :ext_management_system => ems, :hpc_queue => subject, :deleted_on => Time.now.utc)

      expect(subject.hpc_jobs).to contain_exactly(active_job)
      expect(subject.all_hpc_jobs).to contain_exactly(active_job, archived_job)
    end
  end

  describe "#tenant_identity" do
    let!(:admin)  { FactoryBot.create(:user_with_group, :userid => "admin") }
    let(:tenant)  { FactoryBot.create(:tenant) }
    let(:ems)     { FactoryBot.create(:ems_hpc, :tenant => tenant) }

    it "has tenant from the ext_management_system" do
      expect(subject.tenant_identity).to eq(admin)
      expect(subject.tenant_identity.current_group).to eq(tenant.default_miq_group)
      expect(subject.tenant_identity.current_tenant).to eq(tenant)
    end

    it "without an ext_management_system, has the root tenant" do
      subject.ext_management_system = nil

      expect(subject.tenant_identity).to eq(admin)
      expect(subject.tenant_identity.current_tenant).to eq(Tenant.root_tenant)
    end
  end

  describe "#disconnect_inv" do
    it "sets deleted_on and leaves ems_id" do
      subject.disconnect_inv
      expect(subject.deleted_on).not_to be_nil
      expect(subject.ems_id).to eq(ems.id)
      expect(subject.archived?).to be(true)
    end

    it "does not overwrite deleted_on if already archived" do
      subject.disconnect_inv
      original_deleted_on = subject.deleted_on
      subject.disconnect_inv
      expect(subject.deleted_on).to eq(original_deleted_on)
    end
  end
end
