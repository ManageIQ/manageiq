class ManageIQ::Providers::Openstack::CloudManager::Template < ManageIQ::Providers::CloudManager::Template
  belongs_to :cloud_tenant

  supports :smartstate_analysis do
    feature_supported, reason = check_feature_support('smartstate_analysis')
    unless feature_supported
      unsupported_reason_add(:smartstate_analysis, reason)
    end
  end

  supports :provisioning do
    if ext_management_system
      unsupported_reason_add(:provisioning, ext_management_system.unsupported_reason(:provisioning)) unless ext_management_system.supports_provisioning?
    else
      unsupported_reason_add(:provisioning, _('not connected to ems'))
    end
  end

  has_and_belongs_to_many :cloud_tenants,
                          :foreign_key             => "vm_id",
                          :join_table              => "cloud_tenants_vms",
                          :association_foreign_key => "cloud_tenant_id",
                          :class_name              => "ManageIQ::Providers::Openstack::CloudManager::CloudTenant"

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.images.get(ems_ref)
  end

  def perform_metadata_scan(ost)
    require 'OpenStackExtract/MiqOpenStackVm/MiqOpenStackImage'

    image_id = ems_ref
    _log.debug "image_id = #{image_id}"
    ost.scanTime = Time.now.utc unless ost.scanTime

    ems = ext_management_system
    os_handle = ems.openstack_handle

    begin
      miqVm = MiqOpenStackImage.new(image_id, :os_handle => os_handle)
      scan_via_miq_vm(miqVm, ost)
    ensure
      miqVm.unmount if miqVm
    end
  end

  def perform_metadata_sync(ost)
    sync_stashed_metadata(ost)
  end

  # TODO: Does this code need to be reimplemented?
  def proxies4job(_job = nil)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this Image'
    }
  end

  def allocated_disk_storage
    hardware.try(:size_on_disk)
  end

  def has_active_proxy?
    true
  end

  def has_proxy?
    true
  end

  def requires_storage_for_scan?
    false
  end
end
