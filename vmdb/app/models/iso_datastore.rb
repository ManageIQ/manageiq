class IsoDatastore < ActiveRecord::Base
  belongs_to :ext_management_system, :foreign_key => :ems_id
  has_many   :iso_images, :dependent => :destroy

  include ReportableMixin

  virtual_column :name, :type => :string, :uses => :ext_management_system

  def name
    ext_management_system.try(:name)
  end

  def synchronize_advertised_images_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => "synchronize_advertised_images",
      :zone        => self.ext_management_system.try(:my_zone),
      :role        => "ems_operations"
    )
  end

  def advertised_images
    log_header = "MIQ(#{self.class.name}#advertised_images)"
    return [] unless self.ext_management_system.kind_of?(EmsRedhat)

    begin
      self.ext_management_system.with_provider_connection do |rhevm|
        rhevm.iso_images.collect { |image| image[:name] }
      end
    rescue RhevmApiError => err
      $log.error("#{log_header} Error Getting ISO Images on ISO Datastore on Management System <#{self.name}>: #{err.class.name}: #{err}")
      raise
    end
  end

  def synchronize_advertised_images
    log_header = "MIQ(#{self.class.name}#synchronize_advertised_images)"
    log_for    = "ISO Datastore on Management System <#{self.name}>"

    $log.info("#{log_header} Synchronizing images on #{log_for}...")
    db_image_hash = self.iso_images.index_by(&:name)
    advertised_images.each do |image_name|
      if db_image_hash.include?(image_name)
        db_image_hash.delete(image_name)
      else
        self.iso_images.create(:name => image_name)
      end
    end

    db_image_hash.each_value { |image| image.destroy }

    clear_association_cache
    self.update_attribute(:last_refresh_on, Time.now.utc)
    $log.info("#{log_header} Synchronizing images on #{log_for}...Complete")
  rescue RhevmApiError => err
  end

end
