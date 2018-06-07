module Spec
  module Support
    module ChargebackHelper
      def set_tier_param_for(metric, param, value, num_of_tier = 0)
        detail = chargeback_rate.chargeback_rate_details.joins(:chargeable_field).where(:chargeable_fields => { :metric => metric }).first
        tier = detail.chargeback_tiers[num_of_tier]
        tier.send("#{param}=", value)
        tier.save
      end

      def used_average_for(metric, hours_in_interval, resource)
        resource.metric_rollups.sum(&metric) / hours_in_interval
      end

      def add_metric_rollups_for(resources, range, step, metric_rollup_params, trait = :with_data, region = nil)
        range.step_value(step).each do |time|
          Array(resources).each do |resource|
            metric_rollup_params[:id] = region_id_for(MetricRollup, region) if region
            metric_rollup_params[:timestamp]     = time
            metric_rollup_params[:resource_id]   = resource.id
            metric_rollup_params[:resource_name] = resource.name
            params = [:metric_rollup_vm_hr, trait, metric_rollup_params].compact
            resource.metric_rollups << FactoryGirl.create(*params)
          end
        end
      end

      def add_vim_performance_state_for(resources, range, step, state_data)
        range.step_value(step).each do |time|
          Array(resources).each do |resource|
            FactoryGirl.create(:vim_performance_state,
                               :timestamp        => time,
                               :resource         => resource,
                               :state_data       => state_data,
                               :capture_interval => 1.hour)
          end
        end
      end
    end
  end
end
