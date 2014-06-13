# referenced by miq_reports/analytics.yaml
class MiqQueueAnalytic < ActsAsArModel
  set_columns_hash(
    :role                 => :string,
    :age_of_last_in_queue => :integer,
    :age_of_next_in_queue => :integer,
    :messages_in_ready    => :integer,
    :messages_in_process  => :integer
  )

  def self.build_results_for_report_analytics(options = {})
    # Options:
    #   :rpt_type => analytics
    #   :resource_id => 1
    #   :resource_type => "MiqServer"

    scope_conditions = nil
    roles = []

    if options[:resource_type] && options[:resource_id]
      resource = Object.const_get(options[:resource_type]).find(options[:resource_id].to_i)

      case resource
      when MiqServer
        scope_conditions = ["server_guid is NULL OR server_guid = :server_guid", {:server_guid => resource.guid}]
        roles = resource.active_role_names
      when Zone
        scope_conditions = ["zone is NULL OR zone = :zone", {:zone=> resource.name}]
        roles = resource.active_role_names
      else
        roles = ServerRole.all_names
        # MiqEnterprise is really a no-op add to scope_conditions
      end
    end

    # Include messages with no role specified in the report
    (roles.to_miq_a << nil).uniq

    counts_hash = MiqQueue.where(scope_conditions).nested_count_by(%w(role state))
    wait_hash = MiqQueue.where(scope_conditions).wait_times_by_role
    table_rows = roles.collect do |role|
      self.new(
        :role                 => role || "No specified role",
        :age_of_next_in_queue => wait_hash.fetch_path(role, :next) || 0,
        :age_of_last_in_queue => wait_hash.fetch_path(role, :last) || 0,
        :messages_in_ready    => counts_hash.fetch_path(role, "ready") || 0,
        :messages_in_process  => counts_hash.fetch_path(role, "dequeue") || 0
      )
    end

    return [table_rows]
  end
end
