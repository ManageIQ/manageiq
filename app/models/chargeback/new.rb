class Chargeback
  module New
    def self.included(child)
      child.class_eval do
        def calculate_costs(consumption, rates)
          self.fixed_compute_metric = consumption.chargeback_fields_present if consumption.chargeback_fields_present

          rates.each do |rate|
            plan = ManageIQ::Consumption::ShowbackPricePlan.find_or_create_by(:description => rate.description,
                                                                              :name        => rate.description,
                                                                              :resource    => MiqEnterprise.first)

            data = {}
            rate.rate_details_relevant_to(relevant_fields).each do |r|
              r.populate_showback_rate(plan, r, showback_category)
              measure = r.chargeable_field.showback_measure
              dimension, _, _ = r.chargeable_field.showback_dimension
              value = r.chargeable_field.measure(consumption, @options)
              data[measure] ||= {}
              data[measure][dimension] = [value, r.showback_unit(ChargeableField::UNITS[r.chargeable_field.metric])]
            end

            results = plan.calculate_list_of_costs_input(resource_type:  showback_category,
                                                         data:           data,
                                                         start_time:     consumption.instance_variable_get("@start_time"),
                                                         end_time:       consumption.instance_variable_get("@end_time"),
                                                         cycle_duration: @options.duration_of_report_step)

            results.each do |cost_value, sb_rate|
              r = ChargebackRateDetail.find(sb_rate.concept)
              metric = r.chargeable_field.metric
              metric_index = ChargeableField::VIRTUAL_COL_USES.invert[metric] || metric
              metric_value = data[r.chargeable_field.group][metric_index]
              metric_field = [r.chargeable_field.group, r.chargeable_field.source, "metric"].join("_")
              cost_field = [r.chargeable_field.group, r.chargeable_field.source, "cost"].join("_")
              _, total_metric_field, total_field = r.chargeable_field.cost_keys
              self[total_field] = (self[total_field].to_f || 0) + cost_value.to_f
              self[total_metric_field] = (self[total_metric_field].to_f || 0) + cost_value.to_f
              self[cost_field] = cost_value.to_f
              self[metric_field] = metric_value.first.to_f
            end
          end
        end
      end
    end
  end
end
