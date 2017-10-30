module Metering
  def calculate_costs(consumption, _)
    self.fixed_compute_metric = consumption.chargeback_fields_present if consumption.chargeback_fields_present
    self.metering_used_metric = fixed_compute_metric

    relevant_fields.each do |field|
      next unless self.class.report_col_options.include?(field)
      group, source, * = field.split('_')
      chargable_field = ChargeableField.find_by(:group => group, :source => source)
      next if field == "fixed_compute_metric" || chargable_field && chargable_field.metering?
      value = chargable_field.measure_metering(consumption, @options) if chargable_field
      self[field] = (value || 0)
    end
  end
end
