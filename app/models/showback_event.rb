class ShowbackEvent < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  has_many :showback_charges, :dependent => :destroy
  has_many :showback_buckets, :through   => :showback_charges

  validates :start_time, :end_time, :resource, :presence => true
  validate :start_time_before_end_time

  serialize :data, JSON # Implement data column as a JSON

  after_create :generate_data

  def start_time_before_end_time
    errors.add(:start_time, "Start time should be before end time") unless end_time.to_i >= start_time.to_i
  end

  # return the parsing error message if not valid JSON; otherwise nil
  def validate_format
    JSON.parse(data) && nil if data.present?
  rescue JSON::ParserError => err
    err.message
  end

  def generate_data
    self.data = {}
    ShowbackUsageType.all.each do |measure_type|
      next unless resource.type.ends_with?(measure_type.category)
      self.data[measure_type.measure] = {}
      measure_type.dimensions.each do |dim|
        self.data[measure_type.measure][dim] = 0
      end
    end
  end
end
