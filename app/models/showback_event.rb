class ShowbackEvent < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  has_many :showback_charges, :dependent => :destroy
  has_many :showback_buckets, :through   => :showback_charges

  validates :start_time, :end_time, :resource_id, :resource_type, :presence => true
  validate :start_time_before_end_time
  validate :resource_is_real

  serialize :data, JSON # Implement data column as a JSON

  after_create :generate_data

  def start_time_before_end_time
    errors.add(:start_time, "Start time should be before end time") unless end_time.to_i >= start_time.to_i
  end

  def resource_is_real
    errors.add(:resource_type, "Resource should exists") unless resource_type.constantize.exists?(:id => resource_id)
  end

  # return the parsing error message if not valid JSON; otherwise nil
  def validate_format
    JSON.parse(data) && nil if data.present?
  rescue JSON::ParserError => err
    err.message
  end

  private

  def generate_data
    self.data = {}
    ShowbackUsageType.all.each do |measure_type|
      next unless resource_type.ends_with?(measure_type.category)
      self.data[measure_type.measure] = {}
      measure_type.dimensions.each do |dim|
        self.data[measure_type.measure][dim] = 0
      end
    end
  end
end
