class Radar
  extend RollupRadarMixin

  def self.capture(last = nil, label = nil)
    settings = ::Settings.radar
    last  ||= settings.capture_last.to_i_with_method
    label ||= settings.label
    time_range = [(Time.now.utc - last).beginning_of_hour..Time.now.utc.end_of_hour]

    get_hourly_maxes_per_group(label, time_range).each do |row|
      mr = MaxByLabel.find_or_create_by(:timestamp    => row['hourly_timestamp'],
                                        :label_name   => row['label_name'],
                                        :label_value  => row['label_value'],
                                        :project_name => row['container_project_name'])

      cpu_usage_rate_average = mr.cpu_usage_rate_average || 0
      next unless cpu_usage_rate_average < row['max_sum_used_cores']
      mr.update_attributes(
          :cpu_usage_rate_average => row['max_sum_used_cores']
      )
    end
  end
end