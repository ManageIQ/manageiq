class ArbitrationSetting < ApplicationRecord
  validates :name, :presence => true
  validates :display_name, :presence => true

  def self.seed
    seed_data.each do |setting_attrs|
      find_or_initialize_by(:name => setting_attrs[:name]).update_attributes!(setting_attrs)
    end
  end

  def self.seed_file_name
    @seed_file_name ||= File.join(FIXTURE_DIR, 'arbitration_settings.yml')
  end

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end
end
