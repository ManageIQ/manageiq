class ArbitrationSetting < ApplicationRecord
  validates :name, :presence => true
  validates :display_name, :presence => true

  def self.seed
    seed_data.each do |setting_attrs|
      setting = find_by_name(setting_attrs[:name])
      if setting.nil?
        create!(setting_attrs)
        _log.info("Created arbitration setting with parameters #{setting_attrs} ")
      else
        setting.attributes = setting_attrs
        if setting.changed?
          _log.info("Updating setting #{setting_attrs[:name]}")
          setting.save!
        end
      end
    end
  end

  def self.seed_file_name
    @seed_file_name ||= File.join(FIXTURE_DIR, 'arbitration_settings.yml')
  end

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end
end
