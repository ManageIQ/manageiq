class ChargebackRateDetailMeasure < ApplicationRecord
  serialize :units, Array
  serialize :units_display, Array
  validates :name, :presence => true, :length => {:maximum => 100}
  validates :step, :presence => true, :numericality => {:greater_than => 0}
  validates :units, :presence => true, :length => {:minimum => 2}
  validates :units_display, :presence => true, :length => {:minimum => 2}
  validate :units_same_length

  has_many :chargeback_rate_detail, :foreign_key => "chargeback_rate_detail_measure_id"

  def measures
    Hash[units_display.zip(units)]
  end

  private def units_same_length
    unless (units.count == units_display.count)
      errors.add("Units Problem", "Units_display length diferent that the units length")
    end
  end
end
