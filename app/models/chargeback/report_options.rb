class Chargeback
  # ReportOptions are usualy stored in MiqReport.db_options[:options]
  ReportOptions = Struct.new(
    :interval,             # daily | weekly | monthly
    :interval_size,
    :end_interval_offset,
    :owner,                # userid
    :tenant_id,
    :tag,                  # like /managed/environment/prod (Mutually exclusive with :user)
    :provide_id,
    :entity_id,            # 1/2/3.../all rails id of entity
    :service_id,
    :groupby,
    :groupby_tag,
    :userid,
    :ext_options,
  ) do
    def self.new_from_h(hash)
      new(*hash.values_at(*members))
    end
  end
end
