require "inventory_refresh"

RSpec.describe ManageIQ::Providers::Inventory::Persister::Builder::HpcManager do
  let(:ems) { FactoryBot.create(:ems_hpc) }
  let(:persister_class) do
    Class.new(ManageIQ::Providers::Inventory::Persister) do
      def initialize_inventory_collections
      end
    end
  end
  let(:persister) { persister_class.new(ems, InventoryRefresh::TargetCollection.new(:manager => ems)) }
  let(:builder_class) { described_class }

  it "defines hpc_queues collection with disconnect_inv delete_method" do
    data = builder_class.prepare_data(:hpc_queues, persister).to_hash

    expect(data[:model_class]).to eq(HpcQueue)
    expect(data[:delete_method]).to eq(:disconnect_inv)
    expect(data[:association]).to eq(:hpc_queues)
  end

  it "defines hpc_nodes collection with disconnect_inv delete_method" do
    data = builder_class.prepare_data(:hpc_nodes, persister).to_hash

    expect(data[:model_class]).to eq(HpcNode)
    expect(data[:delete_method]).to eq(:disconnect_inv)
    expect(data[:association]).to eq(:hpc_nodes)
  end

  it "defines hpc_jobs collection with disconnect_inv delete_method" do
    data = builder_class.prepare_data(:hpc_jobs, persister).to_hash

    expect(data[:model_class]).to eq(HpcJob)
    expect(data[:delete_method]).to eq(:disconnect_inv)
    expect(data[:association]).to eq(:hpc_jobs)
  end
end
