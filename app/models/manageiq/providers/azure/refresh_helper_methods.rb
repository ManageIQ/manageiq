module ManageIQ::Providers::Azure::RefreshHelperMethods
  extend ActiveSupport::Concern

  def process_collection(collection, key, store_in_data = true)
    @data[key] ||= [] if store_in_data

    return if collection.nil?

    collection.each do |item|
      uid, new_result = yield(item)
      @data[key] << new_result if store_in_data
      @data_index.store_path(key, uid, new_result)
    end
  end

  # Compose an id string combining some existing keys
  def resource_uid(*keys)
    keys.join('\\')
  end

  # For those resources without a location, default to the location of
  # their resource group.
  #
  def gather_data_for_this_region(arm_service, method_name = 'list_all')
    if method_name.to_s == 'list_all'
      arm_service.send(method_name).select do |resource|
        resource.try(:location) == @ems.provider_region
      end.flatten
    elsif method_name.to_s == 'list_all_private_images' # requires special handling
      arm_service.send(method_name, :location => @ems.provider_region)
    else
      resource_groups.collect do |resource_group|
        arm_service.send(method_name, resource_group.name).select do |resource|
          location = resource.respond_to?(:location) ? resource.location : resource_group.location
          location == @ems.provider_region
        end
      end.flatten
    end
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

  def ip_addresses
    @ip_addresses ||= gather_data_for_this_region(@ips)
  end
end
