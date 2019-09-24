Metric
class Metric
  belongs_to :container, :class_name => "Container", :foreign_type => "Container", :foreign_key => :resource_id
end

ContainerImage
class ContainerImage
  has_many :container_image_labels, -> { where(:section => %w(labels docker_labels)) }, :class_name => "CustomAttribute", :as => :resource
end

module RollupRadarMixin
  extend ActiveSupport::Concern

  require 'sqlite3'
  class MaxByLabel < ApplicationRecord
    establish_connection(
      :adapter  => "sqlite3",
      :database => "db/radar.sqlite3"
    )

    unless connection.table_exists?(:max_by_labels)
      connection.create_table :max_by_labels do |t|
        t.datetime :timestamp
        t.string   :label_name
        t.string   :label_value
        t.string   :project_name
        t.float    :cpu_usage_rate_average
      end
    end
  end

  def date_trunc(by, attribute)
    Arel::Nodes::NamedFunction.new(
      'DATE_TRUNC', [Arel.sql("'#{by}'"), attribute]
    )
  end

  def get_hourly_maxes_per_group(label_name, time_range)
    joins_structure = [
      :container => [
        :container_group,
        :container_image => [
          :container_image_labels
        ]
      ]
    ]

    sums_query = Metric.joins(joins_structure)
                       .select(["custom_attributes.name as label_name",
                                "custom_attributes.value as label_value",
                                "container_groups.container_project_id",
                                "metrics.timestamp",
                                "sum((metrics.cpu_usage_rate_average * metrics.derived_vm_numvcpus) / 100.0) AS sum_used_cores"])
                       .where(:resource_type => "Container", :timestamp => time_range, "custom_attributes.name" => label_name)
                       .group(["custom_attributes.name",
                               "custom_attributes.value",
                               "container_groups.container_project_id",
                               "metrics.timestamp"])
                       .order("container_groups.container_project_id") # we have to order by something existing, since rails puts there :id

    # Now lets build an outer query that will pick a max of sum_used_cores, in each group
    sums               = Arel::Table.new(:sums)
    composed_cte       = Arel::Nodes::As.new(sums, Arel.sql("(#{sums_query.to_sql})"))
    container_projects = ContainerProject.arel_table

    shared_project_and_group_by = [
      sums[:label_name],
      sums[:label_value]
    ]

    arel = sums.project(*shared_project_and_group_by,
                        container_projects[:name].as("container_project_name"),
                        date_trunc('hour', sums[:timestamp]).as("hourly_timestamp"),
                        sums[:sum_used_cores].maximum.as("max_sum_used_cores"))
               .join(container_projects).on(container_projects[:id].eq(sums[:container_project_id]))
               .with(composed_cte)
               .group(*shared_project_and_group_by,
                      container_projects[:name],
                      "hourly_timestamp")

    ActiveRecord::Base.connection.execute(arel.to_sql).to_a
  end
end
