class PxeImageType < ActiveRecord::Base
  include ReportableMixin
  has_many :customization_templates
  has_many :pxe_images
  has_many :windows_images
  has_many :iso_images

  validates_uniqueness_of :name

  def self.seed_file_name
    @seed_file_name ||= Rails.root.join("db", "fixtures", "#{self.table_name}.yml")
  end

  def self.seed_data
    File.exists?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end

  def self.seed
    return if PxeImageType.any?

    MiqRegion.my_region.lock do
      seed_data.each do |s|
        $log.info("MIQ(#{self.name}.seed) Creating #{s.inspect}")
        self.create(s)
      end
    end
  end

  def images
    self.pxe_images + self.windows_images
  end

  def esx?
    self.name.to_s.downcase == 'esx'
  end
end
