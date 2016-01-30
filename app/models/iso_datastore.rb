class IsoDatastore < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :iso_datastore
  has_many   :iso_images, :dependent => :destroy

  include ReportableMixin

  virtual_column :name, :type => :string, :uses => :ext_management_system

  def name
    ext_management_system.try(:name)
  end

  def synchronize_advertised_images_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "synchronize_advertised_images",
      :zone        => ext_management_system.try(:my_zone),
      :role        => "ems_operations"
    )
  end

  def advertised_images
    return [] unless ext_management_system.kind_of?(ManageIQ::Providers::Redhat::InfraManager)

    begin
      ext_management_system.with_provider_connection do |rhevm|
        rhevm.iso_images.collect { |image| image[:name] }
      end
    rescue Ovirt::Error => err
      _log.error("Error Getting ISO Images on ISO Datastore on Management System <#{name}>: #{err.class.name}: #{err}")
      raise
    end
  end

  def synchronize_advertised_images
    log_for    = "ISO Datastore on Management System <#{name}>"

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
  rescue Ovirt::Error
  end
end
