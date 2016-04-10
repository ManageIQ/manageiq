require 'ansible_tower_client'

describe ManageIQ::Providers::AnsibleTower::ConfigurationManager::RefreshParser do
  let(:connection) do
    double(:connection,
           :api => double(:api,
                          :hosts         => double(:hosts,         :all => all_hosts),
                          :inventories   => double(:inventories,   :all => all_inventories),
                          :job_templates => double(:job_templates, :all => all_job_templates)
                         )
          )
  end
  let(:parser)            { described_class.new(manager) }
  let(:manager)           { FactoryGirl.create(:configuration_manager_ansible_tower, :provider) }
  let(:mock_api)          { double("AnsibleTowerClient::Api") }
  let(:all_hosts)         { (1..2).collect { |i| AnsibleTowerClient::Host.new(mock_api, "related" => {"inventory" => "url"}, "id" => i, "name" => "host#{i}", "inventory" => i, "instance_id" => "vmwareVm-#{i}") } }
  let(:all_inventories)   { (1..2).collect { |i| AnsibleTowerClient::Inventory.new(mock_api, "id" => i, "name" => "inventory#{i}") } }
  let(:all_job_templates) { (1..2).collect { |i| AnsibleTowerClient::JobTemplate.new(mock_api, "id" => i, "name" => "template#{i}", "description" => "description#{i}", "extra_vars" => "some_json_payload") } }

  it "#configuration_manager_inv_to_hashes" do
    allow_any_instance_of(AnsibleTowerClient::JobTemplate).to receive(:survey_spec).and_return('some_hash_payload')
    expect(manager.provider).to receive(:connect).and_return(connection)

    parser.configuration_manager_inv_to_hashes

    expect(parser.instance_variable_get(:@data)[:configured_systems].count).to eq(2)
    expect(parser.instance_variable_get(:@data)[:configured_systems].first).to eq(
      :manager_ref          => "1",
      :hostname             => "host1",
      :inventory_root_group => {:ems_ref => "1", :name => "inventory1", :type => "ManageIQ::Providers::ConfigurationManager::InventoryRootGroup"},
      :type                 => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem",
      :virtual_instance_ref => "vmwareVm-1"
    )

    expect(parser.instance_variable_get(:@data)[:configuration_scripts].count).to eq(2)
    expect(parser.instance_variable_get(:@data)[:configuration_scripts].first).to eq(
      :manager_ref => "1",
      :name        => "template1",
      :description => "description1",
      :variables   => "some_json_payload",
      :survey_spec => "some_hash_payload"
    )

    expect(parser.instance_variable_get(:@data)[:ems_folders].count).to eq(2)
    expect(parser.instance_variable_get(:@data)[:ems_folders].first).to eq(
      :ems_ref => "1",
      :name    => "inventory1",
      :type    => "ManageIQ::Providers::ConfigurationManager::InventoryRootGroup"
    )
  end
end
