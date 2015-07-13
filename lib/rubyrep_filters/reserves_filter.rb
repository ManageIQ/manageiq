class ReservesFilter
  def filter_conditions
    exclude_tables = MiqReplicationWorker.worker_settings.fetch_path(:replication, :exclude_tables)
    exclude_models = exclude_tables.collect { |t| t.classify if t =~ /^[a-z_]+$/ rescue nil }.compact
    return nil if exclude_models.empty?

    clause = {:resource_type => exclude_models}
    {
      :sync => clause,
      :replicate => {
        :insert => {:new => clause},
        :update => {:new => clause},
        :delete => {:old => clause},
      }
    }
  end
end
