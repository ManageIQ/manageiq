require_migration

describe SeparateAzureNetworkManagerFromAzureCloudManager do
  def name_key(model_name)
    case model_name
      when :floating_ip
        :fixed_ip_address
      else
        :name
    end
  end

  def create_record(x, order, name, network_manager = nil)
    case order
      when :in
        x[name] = send("#{name}_stub").create!(:type          => x[:type_in],
                                               name_key(name) => x[:name],
                                               :ems_id        => x[:ems_in][:ems].id)
      when :out
        case x[:ems_out]
          when 'new_ems'
            x[:ems_out] = {:ems => network_manager}
        end

        x[name] = send("#{name}_stub").create!(:type          => x[:type_out],
                                               name_key(name) => x[:name],
                                               :ems_id        => x[:ems_out][:ems].id)
    end
  end

  def verify_record(x, order, name)
    case order
      when :in
        expect(x[name].reload).to have_attributes(
                                    :type          => x[:type_in],
                                    name_key(name) => x[:name],
                                    :ems_id        => x[:ems_in][:ems].id,
                                  )
      when :out
        expect(x[name].reload).to have_attributes(
                                    :type          => x[:type_out],
                                    name_key(name) => x[:name],
                                  )
        if x[:ems_out].include?("new_ems")
          expect(ems_row_entries.select { |e| e[:ems_in] }).to_not include(x[name].ems_id)
        else
          expect(x[name]).to have_attributes(
                               :ems_id => x[:ems_out][:ems].id,
                             )
        end
    end
  end

  def build_mock_data(model_class_name)
    [
      {
        :ems_in   => ems_row_entries[0],
        :ems_out  => ems_row_entries[0],
        :name     => "name_0",
        :type_in  => "ManageIQ::Providers::Openstack::CloudManager::#{model_class_name}",
        :type_out => "ManageIQ::Providers::Openstack::CloudManager::#{model_class_name}",
      },
      {
        :ems_in   => ems_row_entries[1],
        :ems_out  => ems_row_entries[1],
        :name     => "name_1",
        :type_in  => "ManageIQ::Providers::Openstack::InfraManager::#{model_class_name}",
        :type_out => "ManageIQ::Providers::Openstack::InfraManager::#{model_class_name}",
      },
      {
        :ems_in   => ems_row_entries[2],
        :ems_out  => 'new_ems',
        :name     => "name_2",
        :type_in  => "ManageIQ::Providers::Azure::CloudManager::#{model_class_name}",
        :type_out => "ManageIQ::Providers::Azure::NetworkManager::#{model_class_name}",
      },
      {
        :ems_in   => ems_row_entries[3],
        :ems_out  => ems_row_entries[3],
        :name     => "name_3",
        :type_in  => "ManageIQ::Providers::AnotherManager::CloudManager::#{model_class_name}",
        :type_out => "ManageIQ::Providers::AnotherManager::CloudManager::#{model_class_name}",
      },
    ]
  end

  let(:all_model_names) do
    [
      :cloud_network,
      :cloud_subnet,
      :network_port,
      :network_router,
      :floating_ip,
      :security_group
    ]
  end

  let(:ext_management_system_stub) { migration_stub(:ExtManagementSystem) }
  let(:cloud_network_stub) { migration_stub(:CloudNetwork) }
  let(:cloud_subnet_stub) { migration_stub(:CloudSubnet) }
  let(:network_port_stub) { migration_stub(:NetworkPort) }
  let(:network_router_stub) { migration_stub(:NetworkRouter) }
  let(:floating_ip_stub) { migration_stub(:FloatingIp) }
  let(:security_group_stub) { migration_stub(:SecurityGroup) }

  let(:cloud_networks) { build_mock_data("CloudNetwork") }
  let(:cloud_subnets) { build_mock_data("CloudSubnet") }
  let(:network_ports) { build_mock_data("NetworkPort") }
  let(:network_routers) { build_mock_data("NetworkRouter") }
  let(:floating_ips) { build_mock_data("FloatingIp") }
  let(:security_groups) { build_mock_data("SecurityGroup") }

  let(:ems_row_entries) do
    [
      {:type => "ManageIQ::Providers::Openstack::CloudManager"},
      {:type => "ManageIQ::Providers::Openstack::InfraManager"},
      {:type => "ManageIQ::Providers::Azure::CloudManager"},
      {:type => "ManageIQ::Providers::AnotherManager::CloudManager"}
    ]
  end

  migration_context :up do
    it "migrates a series of representative row" do
      ems_row_entries.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type => x[:type])
      end

      all_model_names.each do |model_name|
        send(model_name.to_s.pluralize).each { |x| create_record(x, :in, model_name) }
      end

      expect(ext_management_system_stub.count).to eq 4

      migrate

      all_model_names.each do |model_name|
        send(model_name.to_s.pluralize).each { |x| verify_record(x, :out, model_name) }
      end

      expect(ext_management_system_stub.count).to eq 5
    end
  end

  migration_context :down do
    it "migrates a series of representative row" do
      ems_row_entries.each do |x|
        x[:ems] = ext_management_system_stub.create!(:type => x[:type])
      end

      network_manager = ext_management_system_stub.create!(
        :name          => "cloud_network",
        :type          => "ManageIQ::Providers::Azure::NetworkManager",
        :parent_ems_id => ems_row_entries[2][:ems].id)

      all_model_names.each do |model_name|
        send(model_name.to_s.pluralize).each { |x| create_record(x, :out, model_name, network_manager) }
      end

      expect(ext_management_system_stub.count).to eq 5

      migrate

      all_model_names.each do |model_name|
        send(model_name.to_s.pluralize).each { |x| verify_record(x, :in, model_name) }
      end

      expect(ext_management_system_stub.count).to eq 4
    end
  end
end
