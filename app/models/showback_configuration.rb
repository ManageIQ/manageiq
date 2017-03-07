class ShowbackConfiguration < ApplicationRecord
  validates :name, :description, :name, :types, :presence => true

  serialize :types, Array # Implement types column as an array
  default_value_for(:types) { [] }

  VALID_MEASURE_TYPES = %w(Occurence Throughput Frequency Capacity Integer).freeze

  validates :measure,
            :inclusion => { :in => VALID_MEASURE_TYPES }

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

  def self.seed_file_name
    @seed_file_name ||= Rails.root.join("db", "fixtures", "#{table_name}.yml")
  end
  private_class_method :seed_file_name

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end
  private_class_method :seed_data
end
