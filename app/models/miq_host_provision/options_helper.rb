module MiqHostProvision::OptionsHelper
  def storage_ids
    @attached_ds ||= options[:attached_ds] || []
  end

  def storages_to_attach
    @storages_to_attach ||= storage_ids.collect { |sid| Storage.find_by(:id => sid) }.compact
  end

  def src_hosts
    @src_hosts ||= options[:src_host_ids].collect { |id_str| Host.find_by(:id => id_str.to_i) }.compact
  end

  def description
    @description ||= _("PXE install on [%{name}] from image [%{id}]") % {:name => host_name,
                                                                         :id   => get_option(:pxe_image_id)}
  end

  def ip_address
    @ip_address ||= get_option(:ip_addr)
  end

  def hostname
    @hostname ||= get_option(:hostname)
  end
end
