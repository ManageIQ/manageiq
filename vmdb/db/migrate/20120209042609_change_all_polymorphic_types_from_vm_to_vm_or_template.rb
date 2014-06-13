require Rails.root.join('lib/migration_helper')

class ChangeAllPolymorphicTypesFromVmToVmOrTemplate < ActiveRecord::Migration
  include MigrationHelper

  self.no_transaction = true

  COLUMNS_TO_UPDATE = [
    # Table                             Column          Index on the column
    [:advanced_settings,                :resource_type, [[:resource_id, :resource_type]]],
    [:audit_events,                     :target_class,  [[:target_id, :target_class]]],
    [:authentications,                  :resource_type, [[:resource_id, :resource_type]]],
    [:binary_blobs,                     :resource_type, [[:resource_id, :resource_type]]],
    [:bottleneck_events,                :resource_type, [[:resource_id, :resource_type]]],
    [:compliances,                      :resource_type, [[:resource_id, :resource_type]]],
    [:custom_attributes,                :resource_type, [[:resource_id, :resource_type]]],
    [:file_depots,                      :resource_type, [[:resource_id, :resource_type]]],
    [:filesystems,                      :resource_type, [[:resource_id, :resource_type]]],
    [:jobs,                             :target_class,  [[:target_id, :target_class]]],
    [:log_files,                        :resource_type, [[:resource_id, :resource_type]]],
    [:miq_alert_statuses,               :resource_type, [[:resource_id, :resource_type]]],
    [:miq_cim_instances,                :vmdb_obj_type, nil],
    [:miq_groups,                       :resource_type, [[:resource_id, :resource_type]]],
    [:miq_widgets,                      :resource_type, [[:resource_id, :resource_type]]],
    [:policy_event_contents,            :resource_type, [[:resource_id, :resource_type]]],
    [:policy_events,                    :target_class,  [[:target_id, :target_class]]],
    [:relationships,                    :resource_type, [[:resource_id, :resource_type, :relationship], {:name => "index_relationships_on_resource_and_relationship"}]],
    [:reserves,                         :resource_type, [[:resource_id, :resource_type]]],
    [:states,                           :resource_type, [[:resource_id, :resource_type]]],
    [:taggings,                         :taggable_type, [[:taggable_id, :taggable_type]]],
    [:vim_performance_operating_ranges, :resource_type, [[:resource_id, :resource_type], {:name => "index_vpor_on_resource"}]],
    [:vim_performance_states,           :resource_type, [[:resource_id, :resource_type, :timestamp], {:name => "index_vim_performance_states_on_resource_and_timestamp"}]],
  ]

  # Append the metrics columns and indexes to COLUMNS_TO_UPDATE
  def self.subtable_name(inherit_from, index)
    "#{inherit_from}_#{index.to_s.rjust(2, '0')}"
  end

  if connection.table_exists?("metrics_00")
    metrics_tables  = (0..23).collect { |n| subtable_name(:metrics, n) }
    metrics_tables += (1..12).collect { |n| subtable_name(:metric_rollups, n) }
  else
    metrics_tables  = [:metrics, :metric_rollups]
  end

  metrics_tables.each do |t|
    COLUMNS_TO_UPDATE << [t, :resource_type, [[:resource_id, :resource_type, :capture_interval_name, :timestamp], {:name => "index_#{t}_on_resource_and_ts"}]]
  end

  def up
    COLUMNS_TO_UPDATE.each do |table, column, index|
      remove_index_ex(table, *index) if index && index_exists?(table, *index)
      change_data(table, column, 'Vm', 'VmOrTemplate')
      add_index(table, *index) if index
    end
  end

  def down
    COLUMNS_TO_UPDATE.each do |table, column, index|
      remove_index_ex(table, *index) if index && index_exists?(table, *index)
      change_data(table, column, 'VmOrTemplate', 'Vm')
      add_index(table, *index) if index
    end
  end
end
