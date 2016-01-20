class AddCreatedOnForContainerEntities < ActiveRecord::Migration
  CONTAINER_TABLES = [:container_nodes, :container_projects, :container_services, :container_routes, :container_groups,
                      :container_replicators, :container_quotas, :container_builds, :container_build_pods,
                      :container_limits, :container_volumes]

  def change
    CONTAINER_TABLES.each do |t|
      add_column t, :created_on, :datetime
      rename_column t, :creation_timestamp, :ems_created_on

      say_with_time("adding created_on datetime to all existing #{t.to_s.tr("_", " ")}") do
        t.to_s.classify.constantize.update_all("created_on=ems_created_on")
      end
    end
  end
end
