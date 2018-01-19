module RollupRadarMixin
  extend ActiveSupport::Concern

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end

  def get_hourly_maxes_per_group(label_name, time_range)
    sums_query = Metric.where(:resource_type => "Container")
                     .where(:timestamp => time_range)
                     .joins("INNER JOIN containers ON metrics.resource_type = 'Container' AND metrics.resource_id = containers.id")
                     .joins("INNER JOIN container_groups ON container_groups.id = containers.container_group_id")
                     .joins("INNER JOIN container_images ON container_images.id = containers.container_image_id")
                     .joins("INNER JOIN custom_attributes ON custom_attributes.name = #{quote(label_name)} AND "\
                      "custom_attributes.resource_type = 'ContainerImage' AND custom_attributes.resource_id = container_images.id")
                     .select("custom_attributes.name as label_name, custom_attributes.value as label_value,"\
                      "container_groups.container_project_id as container_project_id, metrics.timestamp as timestamp, "\
                      "sum((metrics.cpu_usage_rate_average * metrics.derived_vm_numvcpus) / 100.0) AS sum_used_cores, "\
                      "count(*) AS containers_in_group")
                     .group("custom_attributes.name, custom_attributes.value, container_groups.container_project_id, metrics.timestamp")
                     .order("container_groups.container_project_id")

    maxes_query = <<-SQL
    WITH sums AS (
      #{sums_query.to_sql}
    )
    SELECT sums.label_name, sums.label_value, container_projects.name as container_project_name, date_trunc('hour', sums.timestamp) as hourly_timestamp, max(sums.sum_used_cores) as max_sum_used_cores
      FROM sums
        INNER JOIN container_projects ON container_projects.id = sums.container_project_id
        GROUP BY sums.label_name, sums.label_value, container_projects.name, date_trunc('hour', sums.timestamp)
    SQL

    ActiveRecord::Base.connection.execute(maxes_query).to_a
  end
end