class TemplateOpenstack < ManageIQ::Providers::CloudManager::Template
  belongs_to :cloud_tenant

  has_and_belongs_to_many :cloud_tenants,
                          :foreign_key             => "vm_id",
                          :join_table              => "cloud_tenants_vms",
                          :association_foreign_key => "cloud_tenant_id",
                          :class_name              => "CloudTenantOpenstack"

  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.images.get(self.ems_ref)
  end

  def perform_metadata_scan(ost)
    require 'OpenStackExtract/MiqOpenStackVm/MiqOpenStackImage'

    image_id = self.ems_ref
    _log.debug "image_id = #{image_id}"
    ost.scanTime = Time.now.utc unless ost.scanTime

    ems = self.ext_management_system

    #
    # TODO: Convert to use OpenstackHandle.
    #
    fog_compute = ems.connect(:service => "Compute")
    fog_image   = ems.connect(:service => "Image")

    begin
      miqVm = MiqOpenStackImage.new(image_id, :fog_compute => fog_compute, :fog_image => fog_image)
      scan_via_miq_vm(miqVm, ost)
    ensure
      miqVm.unmount if miqVm
    end
  end

  def perform_metadata_sync(ost)
    sync_stashed_metadata(ost)
  end

  # TODO: Does this code need to be reimplemented?
  def proxies4job(job=nil)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this Image'
    }
  end
  def has_active_proxy?
    return true
  end
  def has_proxy?
    return true
  end
end
