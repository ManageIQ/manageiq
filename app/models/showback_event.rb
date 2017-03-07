class ShowbackEvent < ApplicationRecord
  belongs_to :showback_configuration

  validates :data, :start_time, :end_time, :id_obj, :type_obj, :presence => true
  validate :start_time_before_end_time

  def start_time_before_end_time
    if start_time.to_i >= end_time.to_i
      errors.add(:start_time, "Start time should be before end time")
    end
  end

  serialize :data, JSON # Implement data column as a JSON
  default_value_for(:data) { {} }

  # return the parsing error message if not valid JSON; otherwise nil
  def validate_format
    JSON.parse(data) && nil if data.present?
  rescue JSON::ParserError => err
    err.message
  end
end
