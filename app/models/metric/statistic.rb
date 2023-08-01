module Metric::Statistic
  # @param timestamp [String|Time] hourly timestamp used for hourly_rollups (prefer Time)
  def self.calculate_stat_columns(obj, timestamp)
    date_range = VimPerformanceState.get_time_interval(timestamp)
    stats = {}

    if obj.respond_to?(:all_container_groups)
      container_groups = obj.all_container_groups # Get disconnected entities as well
      stats[:stat_container_group_create_rate] = container_groups.where(:ems_created_on => date_range).count
      stats[:stat_container_group_delete_rate] = container_groups.where(:deleted_on => date_range).count
    end

    if obj.respond_to?(:all_container_images)
      stats[:stat_container_image_registration_rate] = obj.all_container_images.where(:registered_on => date_range).count
    end

    stats
  end
end
