module OpsHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_vmdb_connection_properties
    %i(vmdb_connection_name vmdb_connection_ipaddress vmdb_connection_vendor vmdb_connection_version
       vmdb_connection_data_directory vmdb_connection_data_disk vmdb_connection_last_start_time)
  end

  def textual_group_vmdb_tables_most_rows
    %i(vmdb_tables_most_rows)
  end

  def textual_group_vmdb_tables_largest_size
    %i(vmdb_tables_largest_size)
  end

  def textual_group_vmdb_tables_most_wasted_space
    %i(vmdb_tables_most_wasted_space)
  end

  def textual_group_vmdb_connection_capacity_data
    %i(vmdb_connection_timestamp vmdb_connection_total_space vmdb_connection_used_space vmdb_connection_free_space
       vmdb_connection_total_index_nodes vmdb_connection_used_index_nodes vmdb_connection_free_index_nodes)
  end

  def textual_group_tenant_quota_allocations
    %i(tenant_quota_allocations)
  end

  #
  # Items
  #

  def textual_vmdb_connection_name
    {:label => _("Name"), :value => @record.name}
  end

  def textual_vmdb_connection_ipaddress
    {:label => _("IP Address"), :value => @record.ipaddress}
  end

  def textual_vmdb_connection_vendor
    {:label => _("Vendor"), :value => @record.vendor}
  end

  def textual_vmdb_connection_version
    {:label => _("Version"), :value => @record.version}
  end

  def textual_vmdb_connection_data_directory
    {:label => _("Data Directory"), :value => @record.data_directory}
  end

  def textual_vmdb_connection_data_disk
    {:label => _("Data Disk"), :value => @record.data_disk}
  end

  def textual_vmdb_connection_last_start_time
    {:label => _("Last Start Time"), :value => format_timezone(@record.last_start_time)}
  end

  def textual_vmdb_connection_timestamp
    metrics = VmdbDatabase.my_database.latest_hourly_metric
    {:label => _("Last Collection"), :value => metrics && format_timezone(metrics.timestamp)}
  end

  def textual_vmdb_connection_total_space
    metrics = VmdbDatabase.my_database.latest_hourly_metric
    {:label => _("Total Space on Volume"), :value => metrics && number_to_human_size(metrics.disk_total_bytes)}
  end

  def textual_vmdb_connection_free_space
    metrics = VmdbDatabase.my_database.latest_hourly_metric
    {:label => _("Free Space on Volume"), :value => metrics && number_to_human_size(metrics.disk_free_bytes)}
  end

  def textual_vmdb_connection_used_space
    metrics = VmdbDatabase.my_database.latest_hourly_metric
    {:label => _("Used Space on Volume"), :value => metrics && number_to_human_size(metrics.disk_used_bytes)}
  end

  def textual_vmdb_connection_total_index_nodes
    metrics = VmdbDatabase.my_database.latest_hourly_metric
    {:label => _("Total Index Nodes"), :value => metrics && number_with_delimiter(metrics.disk_total_inodes)}
  end

  def textual_vmdb_connection_used_index_nodes
    metrics = VmdbDatabase.my_database.latest_hourly_metric
    {:label => _("Used Index Nodes"), :value => metrics && number_with_delimiter(metrics.disk_used_inodes)}
  end

  def textual_vmdb_connection_free_index_nodes
    metrics = VmdbDatabase.my_database.latest_hourly_metric
    {:label => _("Free Index Nodes"), :value => metrics && number_with_delimiter(metrics.disk_free_inodes)}
  end

  def textual_vmdb_tables_most_rows
    h = {:label     => _("Tables with the Most Rows"),
         :headers   => [_("Name"), _("Rows")],
         :col_order => %w(name value)}
    h[:value] = vmdb_table_top_rows(:rows, TOP_TABLES_BY_ROWS_COUNT)
    h
  end

  def textual_vmdb_tables_largest_size
    h = {:label     => _("Largest Tables"),
         :headers   => [_("Name"), _("Size")],
         :col_order => %w(name value)}
    h[:value] = vmdb_table_top_rows(:size, TOP_TABLES_BY_SIZE_COUNT)
    h
  end

  def textual_vmdb_tables_most_wasted_space
    h = {:label     => _("Tables with Most Wasted Space"),
         :headers   => [_("Name"), _("Wasted")],
         :col_order => %w(name value)}
    h[:value] = vmdb_table_top_rows(:wasted_bytes, TOP_TABLES_BY_WASTED_SPACE_COUNT)
    h
  end

  def vmdb_table_top_rows(typ, limit)
    rows = VmdbDatabase.my_database.top_tables_by(typ, limit)
    rows.collect do |row|
      {
        :title    => row.name,
        :name     => row.name,
        :value    => typ == :rows ? number_with_delimiter(row.latest_hourly_metric.send(typ.to_s), :delimeter => ',') :
                                 number_to_human_size(row.latest_hourly_metric.send(typ.to_s), :precision => 1),
        :explorer => true,
        :link     => "miqDynatreeActivateNode('vmdb_tree', 'tb-#{to_cid(@sb[:vmdb_tables][row.name])}');"
      }
    end
  end

  def textual_tenant_quota_allocations
    h = {:label     => _("Tenant Quota"),
         :headers   => [_("Name"), _("Total Quota"), _("In Use"), _("Allocated"), _("Available")],
         :col_order => %w(name total in_use allocated available)}
    h[:value] = get_tenant_quota_allocations
    h
  end

  def convert_to_format(format, text_modifier, value)
    fmt_value = case format.to_s
                  when "general_number_precision_0"
                    value.to_i
                  when "gigabytes_human"
                    value.to_f / GIGABYTE
                  else
                    value.to_f
                end
    return "#{fmt_value} #{text_modifier}"
  end

  def convert_to_format_with_default_text(format, text_modifier, value, metric)
    is_zero_value = value.nil? || value == 0
    can_display_default_text = !TenantQuota.default_text_for(metric).nil?

    if is_zero_value && can_display_default_text
      return TenantQuota.default_text_for(metric)
    end

    convert_to_format(format, text_modifier, value)
  end

  def get_tenant_quota_allocations
    rows = @record.combined_quotas.values.to_a
    rows.collect do |row|
      {
        :title => row[:description],
        :name => row[:description],
        :in_use => convert_to_format_with_default_text(row[:format], row[:text_modifier], row[:used], :in_use),
        :allocated => convert_to_format_with_default_text(row[:format], row[:text_modifier], row[:allocated],
                                                          :allocated),
        :available => convert_to_format_with_default_text(row[:format], row[:text_modifier], row[:available],
                                                          :available),
        :total => convert_to_format_with_default_text(row[:format], row[:text_modifier], row[:value], :total),
        :explorer => true
      }
    end
  end
end
