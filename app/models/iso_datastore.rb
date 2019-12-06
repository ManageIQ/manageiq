class IsoDatastore < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :iso_datastore
  has_many   :iso_images, :dependent => :destroy

  virtual_column :name, :type => :string, :uses => :ext_management_system

  def name
    ext_management_system.try(:name)
  end

  # Synchronize advertised images as a queued task. The
  # queue name and the queue zone are derived from the EMS.
  #
  def synchronize_advertised_images_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "synchronize_advertised_images",
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.try(:my_zone),
      :role        => "ems_operations"
    )
  end

  def advertised_images
    return [] unless ext_management_system.kind_of?(ManageIQ::Providers::Redhat::InfraManager)

    ext_management_system.ovirt_services.advertised_images
  end

  def synchronize_advertised_images
    log_for = "ISO Datastore on Management System <#{name}>"

    _log.info("Synchronizing images on #{log_for}...")
    db_image_hash = iso_images.index_by(&:name)

    advertised_images.each do |image_name|
      if db_image_hash.include?(image_name)
        db_image_hash.delete(image_name)
      else
        iso_images.create(:name => image_name)
      end
    end

    db_image_hash.each_value(&:destroy)

    clear_association_cache
    update_attribute(:last_refresh_on, Time.now.utc)

    _log.info("Synchronizing images on #{log_for}...Complete")
  rescue ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Error
  end

  def self.display_name(number = 1)
    n_('ISO Datastore', 'ISO Datastores', number)
  end
end
