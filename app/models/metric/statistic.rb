module Metric::Statistic
  def self.calculate_stat_columns(obj, timestamp)
    return {} unless obj.respond_to?(:container_groups)

    capture_interval = Metric::Helper.get_time_interval(obj, timestamp)
    container_groups = ContainerGroup.where(:ems_id => obj.id).or(ContainerGroup.where(:old_ems_id => obj.id))

    {
      :stat_container_group_create_rate => container_groups.where(:created_on => capture_interval).count,
      :stat_container_group_delete_rate => container_groups.where(:deleted_on => capture_interval).count
    }
  end
end
