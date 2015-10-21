class ChargebackRateDetailMeasure < ActiveRecord::Base
  validates :name, :presence => true, :length => {:maximum => 100}
  validates :step, :presence => true, :numericality => {:greater_than => 0}
  validates :units, :presence => true, :length => {:minimum => 2}
  validates :units_display, :presence => true, :length => {:minimum => 2}
  validate :units_same_length

  has_many :chargeback_rate_detail

  def measures
    Hash[units_display.zip(units)]
  end

  private def units_same_length
    unless (units.count == units_display.count)
      errors.add("Units Problem", "Units_display lenght diferent that the units lenght")
    end
  end
end
