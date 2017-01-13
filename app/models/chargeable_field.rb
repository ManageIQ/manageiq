class ChargeableField < ApplicationRecord
  belongs_to :measure, :class_name => 'ChargebackRateDetailMeasure', :foreign_key => :chargeback_rate_detail_measure_id

  validates :metric, :uniqueness => true, :presence => true
  validates :group, :source, :presence => true

  def self.seed_fields
    seed_data.each do |f|
      rec = ChargeableField.find_by(:metric => f[:metric])
      measure = f.delete(:measure)
      if measure
        f[:chargeback_rate_detail_measure_id] = ChargebackRateDetailMeasure.find_by!(:name => measure).id
      end
      if rec.nil?
        create(f)
      else
        rec.update_attributes!(f)
      end
    end
  end

  def self.seed_data
    fixture_file = File.join(FIXTURE_DIR, 'chargeable_fields.yml')
    File.exist?(fixture_file) ? YAML.load_file(fixture_file) : []
  end
end
