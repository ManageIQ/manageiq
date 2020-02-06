require "inventory_refresh"
require_relative 'test_persister'

RSpec.describe ManageIQ::Providers::Inventory::Persister::Builder do
  before :each do
    @ems = FactoryBot.create(:ems_cloud)
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

  # TODO: move to amazon spec
  it "derives existing model_class from persister's class" do
  end

  it "derives existing model_class without persister's class" do
    data = cloud.prepare_data(:vms, persister_class).to_hash

    expect(data[:model_class]).to eq ::Vm
  end

  it "replaces derived model_class if model_class defined manually" do
    data = cloud.prepare_data(:vms, persister_class) do |builder|
      builder.add_properties(:model_class => ::MiqTemplate)
    end.to_hash

    expect(data[:model_class]).to eq ::MiqTemplate
  end

  it "doesn't try to derive model_class when disabled" do
    data = cloud.prepare_data(:vms, persister_class, :without_model_class => true).to_hash

    expect(data[:model_class]).to be_nil
  end

  it 'throws exception if model_class not specified' do
    builder = cloud.prepare_data(:non_existing_ic, persister_class)

    expect { builder.to_inventory_collection }.to raise_error(::ManageIQ::Providers::Inventory::Persister::Builder::MissingModelClassError, /NonExistingIc/)
  end

  # --- adv. settings (TODO: link to gui)---

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

  # --- shared properties ---

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

  # --- properties ---

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

  it "doesn't override properties in :if_missing mode" do
    data = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_properties(:param => 1)
      builder.add_properties({:param => 2}, :if_missing)
    end.to_hash

    expect(data[:param]).to eq 1
  end

  it 'adds property by method_missing' do
    data = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_some_tmp_param(:some_value)
    end.to_hash

    expect(data[:some_tmp_param]).to eq :some_value
  end

  # --- default values ---

  it 'adds default_values repeatedly' do
    data = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_default_values(:ems_id => 10)
      builder.add_default_values(:ems_id => 20)
      builder.add_default_values(:tmp_id => 30)
    end.to_hash

    expect(data[:default_values][:ems_id]).to eq 20
    expect(data[:default_values][:tmp_id]).to eq 30
  end

  it 'transforms lambdas in default_values' do
    bldr = cloud.prepare_data(:tmp, persister_class) do |builder|
      builder.add_default_values(:ems_id => ->(persister) { persister.manager.id })
    end
    bldr.evaluate_lambdas!(@persister)

    data = bldr.to_hash

    expect(data[:default_values][:ems_id]).to eq(@persister.manager.id)
  end

  # --- inventory object attributes ---

  it 'derives inventory object attributes automatically' do
    data = cloud.prepare_data(:vms, persister_class).to_hash

    expect(data[:inventory_object_attributes]).not_to be_empty
  end

  it "doesn't derive inventory_object_attributes automatically when disabled" do
    data = cloud.prepare_data(:vms, persister_class, :auto_inventory_attributes => false).to_hash

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
