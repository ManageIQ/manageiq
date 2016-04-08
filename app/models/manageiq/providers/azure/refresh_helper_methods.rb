module ManageIQ::Providers::Azure::RefreshHelperMethods
  extend ActiveSupport::Concern

  def process_collection(collection, key)
    @data[key] ||= []

    return if collection.nil?

    collection.each do |item|
      uid, new_result = yield(item)
      @data[key] << new_result
      @data_index.store_path(key, uid, new_result)
    end
  end

  # Compose an id string combining some existing keys
  def resource_uid(*keys)
    keys.join('\\')
  end

  def gather_data_for_this_region(arm_service, method = "list")
    resource_groups.collect do |resource_group|
      arm_service.send(method, resource_group.name)
    end.flatten
  end

  def resource_groups
    @resource_groups ||= @rgs.list.select do |resource_group|
      resource_group.location == @ems.provider_region
    end
  end

  # TODO(lsmola) NetworkManager, move below methods under NetworkManager, once it is not needed in Cloudmanager
  def get_vm_nics(instance)
    nic_ids = instance.properties.network_profile.network_interfaces.collect(&:id)
    network_interfaces.find_all { |nic| nic_ids.include?(nic.id) }
  end

  def network_interfaces
    @network_interfaces ||= gather_data_for_this_region(@nis)
  end
end
