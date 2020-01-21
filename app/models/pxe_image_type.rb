class PxeImageType < ApplicationRecord
  has_many :customization_templates
  has_many :pxe_images
  has_many :windows_images
  has_many :iso_images

  validates :name, :unique_within_region => true

  def self.seed_file_name
    @seed_file_name ||= Rails.root.join("db", "fixtures", "#{table_name}.yml")
  end

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end

  def self.seed
    return if any?

    seed_data.each do |s|
      _log.info("Creating #{s.inspect}")
      create!(s)
    end
  end

  def images
    pxe_images + windows_images
  end

  def esx?
    name.to_s.downcase == 'esx'
  end

  def self.display_name(number = 1)
    n_('Image Type', 'Image Types', number)
  end
end
