class ShowbackMeasureType < ApplicationRecord
  validates :description, :dimensions, :presence => true

  VALID_CATEGORY = %w(VmOrTemplate).freeze
  validates :category,
            :inclusion => { :in => VALID_CATEGORY }

  VALID_MEASURE_TYPES = %w(CPU).freeze
  validates :measure,
            :inclusion => { :in => VALID_MEASURE_TYPES }

  VALID_DIMENSIONS = %w(average number max_number_of_cpu).freeze
  validate :validate_dimensions_measures

  def self.seed
    seed_data.each do |measure_type_attributtes|
      measure_type_name = measure_type_attributtes[:category]
      measure_type_measure = measure_type_attributtes[:measure]
      next if ShowbackMeasureType.find_by(:category => measure_type_name, :measure => measure_type_measure)
      log_attrs = measure_type_attributtes.slice(:category, :description, :measure, :dimensions)
      _log.info("Creating consumption measure type with parameters #{log_attrs.inspect}")
      _log.info("Creating #{measure_type_name} consumption measure type...")
      measure_new = create(measure_type_attributtes)
      measure_new.save
      _log.info("Creating #{measure_type_name} consumption measure type... Complete")
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
