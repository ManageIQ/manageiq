class ShowbackUsageType < ApplicationRecord
  validates :description, :dimensions, :presence => true

  VALID_CATEGORY = %w(Vm).freeze
  validates :category,
            :inclusion => { :in => VALID_CATEGORY }

  VALID_USAGE_TYPES = %w(CPU).freeze
  validates :measure,
            :inclusion => { :in => VALID_USAGE_TYPES }

  VALID_DIMENSIONS = %w(average number max_number_of_cpu).freeze
  validate :validate_dimensions_measures

  def self.seed
    seed_data.each do |usage_type_attributtes|
      usage_type_name = usage_type_attributtes[:category]
      usage_type_measure = usage_type_attributtes[:measure]
      next if ShowbackUsageType.find_by(:category => usage_type_name, :measure => usage_type_measure)
      log_attrs = usage_type_attributtes.slice(:category, :description, :measure, :dimensions)
      _log.info("Creating consumption usage type with parameters #{log_attrs.inspect}")
      _log.info("Creating #{usage_type_name} consumption usage type...")
      usage_new = create(usage_type_attributtes)
      usage_new.save
      _log.info("Creating #{usage_type_name} consumption usage type... Complete")
    end
  end

  private

  def self.seed_file_name
    @seed_file_name ||= Rails.root.join("db", "fixtures", "#{table_name}.yml")
  end

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end

  def validate_dimensions_measures
    if (invalid_dimensions = (dimensions - VALID_DIMENSIONS))
      invalid_dimensions.each do |dim|
        errors.add(:dimensions, dim + " is not a valid measure dimension")
      end
    end
  end
end
