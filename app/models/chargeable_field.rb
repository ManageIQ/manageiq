class ChargeableField < ApplicationRecord
  belongs_to :measure, :class_name => 'ChargebackRateDetailMeasure', :foreign_key => :chargeback_rate_detail_measure_id

  validates :metric, :uniqueness => true, :presence => true
  validates :group, :source, :presence => true
end
