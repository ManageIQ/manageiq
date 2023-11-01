RSpec.describe ManageIQ::DeepDelete do
  let(:ems) { FactoryBot.create(:ems_container) }
  let(:ems_other) { FactoryBot.create(:ems_container) }

  it "calls destroy for objects with ruby callbacks" do
    expect_any_instance_of(ems.class).to receive(:destroy)

    described_class.delete(ems)
  end

  it "deletes Ems#has_many" do
    child1 = FactoryBot.create(:storage, :ext_management_system => ems)
    child2 = FactoryBot.create(:storage, :ext_management_system => ems_other)
    described_class.delete(ems)

    expect(child1).to be_deleted
    expect(child2).not_to be_deleted
  end

  it "nulls out Ems#has_many" do
    child1 = FactoryBot.create(:vm, :ext_management_system => ems)
    child2 = FactoryBot.create(:vm, :ext_management_system => ems_other)
    described_class.delete(ems)

    expect(child1.reload.ext_management_system).to eq(nil)
    expect(child2.reload.ext_management_system).to eq(ems_other)
  end

  it "deletes (child STI class) ContainerManager#has_many" do
    child1 = FactoryBot.create(:container_service, :ext_management_system => ems)
    child2 = FactoryBot.create(:container_service, :ext_management_system => ems_other)

    described_class.delete(ExtManagementSystem.where(:id => ems.id))
    expect(child1).to be_deleted
    expect(child2).not_to be_deleted
  end

  it "deletes has_many :through deletes the join record not the target record" do
    ems = FactoryBot.create(:ems_cloud)
    net_ems     = ems.network_manager
    subnet      = FactoryBot.create(:cloud_subnet, :ext_management_system => net_ems)
    # has_many :cloud_subnet_network_port, :dependent => destroy
    # has_many :network_ports, :through => :cloud_subnet_network_ports
    # we've since moved the :dependent => :destroy from network_ports, to cloud_subnet_network_port
    # but it would have the same outcome
    net_port    = FactoryBot.create(:network_port, :ext_management_system => net_ems)
    subnet_port = FactoryBot.create(:cloud_subnet_network_port, :cloud_subnet => subnet, :network_port => net_port)

    described_class.delete(subnet)

    expect(subnet).to be_deleted
    expect(net_port).not_to be_deleted
    expect(subnet_port).to be_deleted
  end
end
