require_relative '../persister/test_persister'

describe ManagerRefresh::InventoryCollection::Builder do
  before :each do
    @zone = FactoryGirl.create(:zone)
    @ems  = FactoryGirl.create(:ems_cloud,
                               :zone            => @zone,
                               :network_manager => FactoryGirl.create(:ems_network, :zone => @zone))
  end

  def create_persister
    TestPersister.new(@ems, ManagerRefresh::TargetCollection.new(:manager => @ems))
  end

  let(:persister_class) { ::ManagerRefresh::Inventory::Persister }

  let(:persister) { create_persister }

  let(:adv_settings) { {:strategy => :local_db_find_missing_references, :saver_strategy => :concurrent_safe_batch} }

  def cloud
    ::ManagerRefresh::InventoryCollection::Builder::CloudManager
  end

  before :each do
  end

  # association

  it 'assigns association automatically to InventoryCollection' do
    ic = cloud.prepare_data(:vms, persister_class).to_inventory_collection

    expect(ic.association).to eq :vms
  end

  # model_class

  # TODO: move to amazon spec
  it "derives existing model_class from persister's class" do
  end

  it "derives existing model_class without persister's class" do
    data = cloud.prepare_data(:vms, persister_class).to_hash

    expect(data[:model_class]).to eq ::Vm
  end

  it "replaces derived model_class if model_class defined manually" do
    data = cloud.prepare_data(:xxx, persister_class) do |builder|
      builder.add_properties(:model_class => ::Vm)
    end.to_hash

    expect(data[:model_class]).to eq ::Vm
  end

  it "doesn't try to derive model_class when disabled" do
    data = cloud.prepare_data(:vms, persister_class, :auto_model_class => false).to_hash

    expect(data[:model_class]).to be_nil
  end

  it 'throws exception if model_class not specified' do
    builder = cloud.prepare_data(:vms, persister_class, :auto_model_class => false)

    expect { builder.to_inventory_collection }.to raise_error(::ManagerRefresh::InventoryCollection::Builder::MissingModelClassError)
  end

  # Adv settings

  it 'works without Advanced settings' do
    builder = cloud.prepare_data(:vms, persister_class, :adv_settings_enabled => false)

    expect { builder.to_inventory_collection }.not_to raise_error
  end

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

  # Shared properties

  it 'applies shared properties' do
    data = cloud.prepare_data(:tmp, persister_class, :shared_properties => {:uuid => 1}).to_hash

    expect(data[:uuid]).to eq 1
  end

  it "doesn't overwrite defined properties by shared properties" do
    data = cloud.prepare_data(:tmp, persister_class, :shared_properties => {:uuid => 1}) do |builder|
      builder.add_properties(:uuid => 2)
    end.to_hash

    expect(data[:uuid]).to eq 2
  end

  # Properties

  it 'adds properties with add_properties repeatedly' do
    data = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_properties(:first => 1, :second => 2)
      builder.add_properties(:third => 3)
    end.to_hash

    expect(data[:first]).to eq 1
    expect(data[:second]).to eq 2
    expect(data[:third]).to eq 3
  end

  it 'overrides properties in :overwrite mode' do
    data = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_properties(:param => 1)
      builder.add_properties({:param => 2}, :overwrite)
    end.to_hash

    expect(data[:param]).to eq 2
  end

  it "doesn't override properties in :missing mode" do
    data = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_properties(:param => 1)
      builder.add_properties({:param => 2}, :missing)
    end.to_hash

    expect(data[:param]).to eq 1
  end

  it 'adds property by method_missing' do
    data = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_some_tmp_param(:some_value)
    end.to_hash

    expect(data[:some_tmp_param]).to eq :some_value
  end

  # Builder params

  it 'adds builder_params repeatedly' do
    data = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_builder_params(:ems_id => 10)
      builder.add_builder_params(:ems_id => 20)
    end.to_hash

    expect(data[:builder_params][:ems_id]).to eq 20
  end

  it 'transforms lambdas in builder_params' do
    bldr = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_builder_params(:ems_id => ->(persister) { persister.manager.id })
    end
    bldr.transform_builder_params(persister)

    data = bldr.to_hash

    expect(data[:builder_params][:ems_id]).to eq(persister.manager.id)
  end

  # Inventory object attributes

  it 'derives inventory object attributes automatically' do
    data = cloud.prepare_data(:vms, persister_class).to_hash

    expect(data[:inventory_object_attributes]).not_to be_empty
  end

  it "doesn't derive inventory_object_attributes automatically when disabled" do
    data = cloud.prepare_data(:vms, persister_class, :auto_object_attributes => false).to_hash

    expect(data[:inventory_object_attributes]).to be_empty
  end

  it 'can add inventory_object_attributes manually' do
    data = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_inventory_attributes(%i(attr1 attr2 attr3))
    end.to_hash

    expect(data[:inventory_object_attributes]).to match_array(%i(attr1 attr2 attr3))
  end

  it 'can remove inventory_object_attributes' do
    data = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_inventory_attributes(%i(attr1 attr2 attr3))
      builder.remove_inventory_attributes(%i(attr2))
    end.to_hash

    expect(data[:inventory_object_attributes]).to match_array(%i(attr1 attr3))
  end

  it 'can clear all inventory_object_attributes' do
    data = cloud.prepare_data(:vms, persister_class) do |builder|
      builder.add_inventory_attributes(%i(attr1 attr2 attr3))
      builder.clear_inventory_attributes!
    end.to_hash

    expect(data[:inventory_object_attributes]).to be_empty
  end
end
