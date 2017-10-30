module Metering
  def calculate_costs(consumption, _)
    self.fixed_compute_metric = consumption.chargeback_fields_present if consumption.chargeback_fields_present

    relevant_fields.each do |field|
      next unless self.class.report_col_options.include?(field)
      group, source, * = field.split('_')
      chargable_field = ChargeableField.find_by(:group => group, :source => source)
      value = chargable_field.measure_metering(consumption, @options) if chargable_field
      self[field] = (value || 0) unless field == 'fixed_compute_metric'
    end
  end
end
