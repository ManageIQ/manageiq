module Metric::Statistic
  def self.calculate_stat_columns(obj, timestamp)
    capture_interval = Metric::Helper.get_time_interval(obj, timestamp)
    stats = {}

    if obj.respond_to?(:all_container_groups)
      container_groups = obj.all_container_groups # Get disconnected entities as well
      stats[:stat_container_group_create_rate] = container_groups.where(:ems_created_on => capture_interval).count
      stats[:stat_container_group_delete_rate] = container_groups.where(:deleted_on => capture_interval).count
    end

    if obj.respond_to?(:all_container_images)
      stats[:stat_container_image_registration_rate] = obj.all_container_images.where(:registered_on => capture_interval).count
    end

    stats
  end
end
