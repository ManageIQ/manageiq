class ShowbackMeasureType < ApplicationRecord
  validates :name, :description, :measure, :types, :presence => true

  VALID_MEASURE_TYPES = %w(CPU).freeze

  validates :measure,
            :inclusion => { :in => VALID_MEASURE_TYPES }

  VALID_TYPES = %w(average number).freeze
  validate :validate_types_measures


  def self.seed
    seed_data.each do |con_conf_attributtes|
      con_conf_name = con_conf_attributtes[:name]
      next if ShowbackConfiguration.find_by(:name => con_conf_name)
      log_attrs = con_conf_attributtes.slice(:name, :description, :measure, :types)
      _log.info("Creating consumption configuration with parameters #{log_attrs.inspect}")
      _log.info("Creating #{con_conf_name} consumption configuration...")
      con_conf = create(con_conf_attributtes)
      con_conf.save
      _log.info("Creating #{con_conf_name} consumption configuration... Complete")
    end
  end

  private∫

  def self.seed_file_name
    @seed_file_name ||= Rails.root.join("db", "fixtures", "#{table_name}.yml")
  end

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end

  def validate_types_measures
    if (invalid_interests = (types - VALID_TYPES))
      invalid_interests.each do |type|
        errors.add(:types, type + " is not a valid measure type")
      end
    end
  end
end
