class ChargebackRateDetailMeasure < ApplicationRecord
  serialize :units, Array
  serialize :units_display, Array
  validates :name, :presence => true, :length => {:maximum => 100}
  validates :step, :presence => true, :numericality => {:greater_than => 0}
  validates :units, :presence => true, :length => {:minimum => 2}
  validates :units_display, :presence => true, :length => {:minimum => 2}
  validate :units_same_length

  def measures
    Hash[units_display.zip(units)]
  end

  def adjust(from_unit, to_unit)
    return 1 if from_unit == to_unit
    jumps = units.index(to_unit) - units.index(from_unit)
    BigDecimal(step)**jumps
  end

  private def units_same_length
    unless (units.count == units_display.count)
      errors.add("Units Problem", "Units_display length diferent that the units length")
    end
  end

  def self.seed
    fixture_file_measure = File.join(FIXTURE_DIR, "chargeback_rates_measures.yml")
    if File.exist?(fixture_file_measure)
      fixture = YAML.load_file(fixture_file_measure)
      fixture.each do |cbr|
        rec = ChargebackRateDetailMeasure.find_by(:name => cbr[:name])
        if rec.nil?
          _log.info("Creating [#{cbr[:name]}] with units=[#{cbr[:units]}]")
          rec = ChargebackRateDetailMeasure.create(cbr)
        else
          fixture_mtime = File.mtime(fixture_file_measure).utc
          if fixture_mtime > rec.created_at
            _log.info("Updating [#{cbr[:name]}] with units=[#{cbr[:units]}]")
            rec.update!(cbr.merge(:created_at => fixture_mtime))
          end
        end
      end
    end
  end
end
