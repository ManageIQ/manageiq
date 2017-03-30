class ShowbackEvent < ApplicationRecord
  belongs_to :showback_configuration

  has_many :showback_charges, dependent: :destroy
  has_many :showback_buckets, through: :showback_charges

  validates :start_time, :end_time, :resource_id, :resource_type, :presence => true
  validate :start_time_before_end_time
  validate :resource_is_real

  def start_time_before_end_time
    if start_time.to_i >= end_time.to_i
      errors.add(:start_time, "Start time should be before end time")
    end
  end

  def resource_is_real
    if !resource_type.constantize.exists?(:id => resource_id)
      errors.add(:resource_type, "Resource should exists")
    end
  end

  serialize :data, JSON # Implement data column as a JSON
  default_value_for(:data) {
    hash = {}
    ShowbackMeasureType.all.each do |measure_type|
      next unless measure_type.category == resource_type
      hash[measure_type.measure] = {}
      measure_type.dimensions.each do |dim|
        hash[measure_type.measure][dim] = 0
      end
    end
    hash
  }

  # return the parsing error message if not valid JSON; otherwise nil
  def validate_format
    JSON.parse(data) && nil if data.present?
  rescue JSON::ParserError => err
    err.message
  end
end
