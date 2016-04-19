module ManageIQ::Providers::Azure::CloudManager::Provision::Cloning
  def do_clone_task_check(clone_task_ref)
    source.with_provider_connection do |azure|
      vms      = Azure::Armrest::VirtualMachineService.new(azure)
      instance = vms.get(clone_task_ref[:vm_name], clone_task_ref[:vm_resource_group])
      status   = instance.properties.provisioning_state
      return true if status == "Succeeded"
      return false, status
    end
  end

  def find_destination_in_vmdb(vm_uid_hash)
    ems_ref = vm_uid_hash.values.join("\\")
    ManageIQ::Providers::Azure::CloudManager::Vm.find_by(:ems_ref => ems_ref.downcase)
  end

  def gather_storage_account_properties
    sas = nil
    source.with_provider_connection do |azure|
      sas = Azure::Armrest::StorageAccountService.new(azure)
    end
    return if sas.nil?

    begin
      key             = sas.list_account_keys(storage_account_name, storage_account_resource_group).fetch('key1')
      storage_account = sas.get(storage_account_name, storage_account_resource_group)
      blob            = storage_account.blobs("system", key).first
      blob_properties = storage_account.blob_properties(blob.container, blob.name, key)
      endpoint        = storage_account.properties.primary_endpoints.blob
      source_uri      = File.join(endpoint, blob.container, blob.name)
      target_uri      = File.join(endpoint, "manageiq", dest_name + "_" + SecureRandom.uuid + ".vhd")
    rescue Azure::Armrest::ResourceNotFoundException => err
      _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
    end

    return target_uri, source_uri, blob_properties.x_ms_meta_microsoftazurecompute_ostype
  end

  def custom_data
    Base64.encode64(userdata_payload.encode("UTF-8")).delete("\n")
  end

  def prepare_for_clone_task
    nic_id = create_nic
    target_uri, source_uri, os = gather_storage_account_properties

    cloud_options =
    {
      :name       => dest_name,
      :location   => source.location,
      :properties => {
        :hardwareProfile => {
          :vmSize => instance_type.name
        },
        :osProfile       => {
          :adminUserName => options[:root_username],
          :adminPassword => root_password,
          :computerName  => dest_name
        },
        :storageProfile  => {
          :osDisk        => {
            :createOption => 'FromImage',
            :caching      => 'ReadWrite',
            :name         => dest_name + SecureRandom.uuid + '.vhd',
            :osType       => os,
            :image        => {:uri => source_uri},
            :vhd          => {:uri => target_uri},
          }
        },
        :networkProfile  => {
          :networkInterfaces => [{:id => nic_id}],
        }
      }
    }
    cloud_options[:properties][:osProfile][:customData] = custom_data unless userdata_payload.nil?
    cloud_options
  end

  def log_clone_options(clone_options)
    dumpObj(clone_options, "#{_log.prefix} Clone Options: ", $log, :info)
    dumpObj(options, "#{_log.prefix} Prov Options:  ", $log, :info, :protected =>
    {:path => workflow_class.encrypted_options_field_regs})
  end

  def region
    source.location
  end

  def storage_account_resource_group
    source.description.split("\\").first
  end

  def storage_account_name
    source.description.split("\\")[1]
  end

  def create_nic
    source.with_provider_connection do |azure|
      nis = Azure::Armrest::Network::NetworkInterfaceService.new(azure)
      ips = Azure::Armrest::Network::IpAddressService.new(azure)

      ip = ips.create("#{dest_name}-publicIp", resource_group.name, :location => region)
      network_options = {
        :location   => region,
        :properties => {
          :ipConfigurations     => [
            :name       => dest_name,
            :properties => {
              :subnet          => {
                :id            => cloud_subnet.ems_ref
              },
              :publicIPAddress => {
                :id => ip.id
              },
            }
          ],
        }
      }
      network_options[:properties][:networkSecurityGroup] = {:id => security_group.ems_ref} if security_group

      return nis.create(dest_name, resource_group.name, network_options).id
    end
  end

  def start_clone(clone_options)
    source.with_provider_connection do |azure|
      vms = Azure::Armrest::VirtualMachineService.new(azure)
      vm  = vms.create(dest_name, resource_group.name, clone_options)
      subscription_id = vm.id.split('/')[2]

      {
        :subscription_id   => subscription_id,
        :vm_resource_group => vm.resource_group,
        :type              => vm.type.downcase,
        :vm_name           => vm.name
      }
    end
  end
end
