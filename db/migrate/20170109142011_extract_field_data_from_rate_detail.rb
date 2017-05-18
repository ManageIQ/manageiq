class ExtractFieldDataFromRateDetail < ActiveRecord::Migration[5.0]
  class ChargebackRate < ActiveRecord::Base
  end

  class ChargeableField < ActiveRecord::Base
  end

  class ChargebackRateDetail < ActiveRecord::Base
    belongs_to :chargeback_rate
    belongs_to :chargeable_field

    def to_h
      { :metric => metric, :source => source, :group => group, :description => description,
        :chargeback_rate_detail_measure_id => chargeback_rate_detail_measure_id }
    end

    def metric
      # fixed_compute_n and fixed_storage_n had metric=nil, we need it to have metric!=nil so we can reference it
      self[:metric] || "#{group}_#{source}"
    end
  end

  def up
    # Cannot create in bulk, there are inconsistencies in the database. One would think that
    # (:metric, :source, :group, :description) quaternion depends is function of :metric.
    # Unfortunatelly it may not be. And we want it to be.
    fields_cache = {}
    ChargebackRateDetail.joins(:chargeback_rate).where(:chargeback_rates => {:default => true}).each do |rate|
      rate.chargeable_field = ChargeableField.create!(rate.to_h)
      rate.save!
      fields_cache[rate.metric] = rate.chargeable_field
    end

    ChargebackRateDetail.where(:chargeable_field_id => nil).each do |rate|
      rate.chargeable_field = fields_cache[rate.metric]
      rate.save!
    end
  end
end
