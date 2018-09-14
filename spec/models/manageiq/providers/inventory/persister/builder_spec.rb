require "inventory_refresh"
require_relative 'test_persister'

describe ManageIQ::Providers::Inventory::Persister::Builder do
  before :each do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_cloud,
                               :zone            => @zone,
                               :network_manager => FactoryGirl.create(:ems_network, :zone => @zone))
    @persister = create_persister
  end

  def create_persister
    TestPersister.new(@ems, InventoryRefresh::TargetCollection.new(:manager => @ems))
  end

  let(:adv_settings) { {:strategy => :local_db_find_missing_references, :saver_strategy => :concurrent_safe_batch} }

  let(:cloud) { ::ManageIQ::Providers::Inventory::Persister::Builder::CloudManager }

  let(:network) { ::ManageIQ::Providers::Inventory::Persister::Builder::NetworkManager }

  let(:persister_class) { ::ManageIQ::Providers::Inventory::Persister }

  # --- association ---

  it 'assigns association automatically to InventoryCollection' do
    ic = cloud.prepare_data(:vms, persister_class).to_inventory_collection

    expect(ic.association).to eq :vms
  end

  # --- model_class ---

  # TODO (mslemr) how to
  it "derives existing model_class from persister's class" do
  end

  # --- adv. settings ---

  it 'assigns Advanced settings' do
    builder = cloud.prepare_data(:tmp, persister_class, :adv_settings => adv_settings)
    data = builder.to_hash

    expect(data[:strategy]).to eq :local_db_find_missing_references
    expect(data[:saver_strategy]).to eq :concurrent_safe_batch
  end

  it "doesn't overwrite defined properties by Advanced settings" do
    data = cloud.prepare_data(:vms, persister_class, :adv_settings => adv_settings) do |builder|
      builder.add_properties(:strategy => :custom)
    end.to_hash

    expect(data[:strategy]).to eq :custom
    expect(data[:saver_strategy]).to eq :default
  end

  # --- shared definitions ---

  it 'applies shared properties and values' do
    data = cloud.prepare_data(:miq_templates, persister_class).to_hash

    expect(data[:custom_reconnect_block]).not_to be_nil
    expect(data[:default_values][:template]).to be_truthy
  end

  it 'applied cloud properties and values' do
    data = cloud.prepare_data(:key_pairs, persister_class).to_hash

    expect(data[:manager_ref]).to eq(%i(name))
    expect(data[:default_values][:resource_id]).not_to be_nil
  end

  # --- inventory object attributes ---

  it 'derives inventory object attributes automatically' do
    data = cloud.prepare_data(:vms, persister_class).to_hash

    expect(data[:inventory_object_attributes]).not_to be_empty
  end
end
