class ChargebackVm < Chargeback
  set_columns_hash(
    :start_date               => :datetime,
    :end_date                 => :datetime,
    :interval_name            => :string,
    :display_range            => :string,
    :vm_name                  => :string,
    :owner_name               => :string,
    :provider_name            => :string,
    :provider_uid             => :string,
    :cpu_allocated_metric     => :float,
    :cpu_allocated_cost       => :float,
    :cpu_used_cost            => :float,
    :cpu_used_metric          => :float,
    :cpu_cost                 => :float,
    :cpu_metric               => :float,
    :disk_io_used_cost        => :float,
    :disk_io_used_metric      => :float,
    :disk_io_cost             => :float,
    :disk_io_metric           => :float,
    :fixed_compute_1_cost     => :float,
    :fixed_compute_2_cost     => :float,
    :fixed_storage_1_cost     => :float,
    :fixed_storage_2_cost     => :float,
    :fixed_2_cost             => :float,
    :fixed_cost               => :float,
    :memory_allocated_cost    => :float,
    :memory_allocated_metric  => :float,
    :memory_used_cost         => :float,
    :memory_used_metric       => :float,
    :memory_cost              => :float,
    :memory_metric            => :float,
    :net_io_used_cost         => :float,
    :net_io_used_metric       => :float,
    :net_io_cost              => :float,
    :net_io_metric            => :float,
    :storage_allocated_cost   => :float,
    :storage_allocated_metric => :float,
    :storage_used_cost        => :float,
    :storage_used_metric      => :float,
    :storage_cost             => :float,
    :storage_metric           => :float,
    :total_cost               => :float
  )

  def self.build_results_for_report_ChargebackVm(options)
    # Options:
    #   :rpt_type => chargeback
    #   :interval => daily | weekly | monthly
    #   :start_time
    #   :end_time
    #   :end_interval_offset
    #   :interval_size
    #   :owner => <userid>
    #   :tag => /managed/environment/prod (Mutually exclusive with :user)
    #   :chargeback_type => detail | summary

    @report_user = User.find_by(:userid => options[:userid])

    # Find Vms by user or by tag
    if options[:owner]
      user = User.find_by_userid(options[:owner])
      if user.nil?
        _log.error("Unable to find user '#{options[:owner]}'. Calculating chargeback costs aborted.")
        raise MiqException::Error, _("Unable to find user '%{name}'") % {:name => options[:owner]}
      end
      vms = user.vms
    elsif options[:tag]
      vms = Vm.find_tagged_with(:all => options[:tag], :ns => "*")
      vms &= @report_user.accessible_vms if @report_user && @report_user.self_service?
    elsif options[:tenant_id]
      tenant = Tenant.find(options[:tenant_id])
      if tenant.nil?
        _log.error("Unable to find tenant '#{options[:tenant_id]}'. Calculating chargeback costs aborted.")
        raise MiqException::Error, "Unable to find tenant '#{options[:tenant_id]}'"
      end
      vms = tenant.vms
    else
      raise _("must provide options :owner or :tag")
    end
    return [[]] if vms.empty?

    @vm_owners = vms.inject({}) { |h, v| h[v.id] = v.evm_owner_name; h }

    build_results_for_report_chargeback(options)
  end

  def self.get_keys_and_extra_fields(perf, ts_key)
    key = "#{perf.resource_id}_#{ts_key}"
    @vm_owners[perf.resource_id] ||= perf.resource.evm_owner_name

    extra_fields = {"vm_name" => perf.resource_name, "owner_name" => @vm_owners[perf.resource_id],
                    "provider_name" => perf.parent_ems.name, "provider_uid" => perf.parent_ems.guid}

    [key, extra_fields]
  end

  def self.where_clause(records, options)
    if options[:tag] && (@report_user.nil? || !@report_user.self_service?)
      records.where(:resource_type => "VmOrTemplate")
          .where.not(:resource_id => nil)
          .for_tag_names(options[:tag].split("/")[2..-1])
    else
      records.where(:resource_type => "VmOrTemplate", :resource_id => @vm_owners.keys)
    end
  end

  def self.report_name_field
    "vm_name"
  end

  def self.report_col_options
    {
      "cpu_allocated_cost"       => {:grouping => [:total]},
      "cpu_allocated_metric"     => {:grouping => [:total]},
      "cpu_cost"                 => {:grouping => [:total]},
      "cpu_metric"               => {:grouping => [:total]},
      "cpu_used_cost"            => {:grouping => [:total]},
      "cpu_used_metric"          => {:grouping => [:total]},
      "disk_io_cost"             => {:grouping => [:total]},
      "disk_io_metric"           => {:grouping => [:total]},
      "disk_io_used_cost"        => {:grouping => [:total]},
      "disk_io_used_metric"      => {:grouping => [:total]},
      "fixed_compute_1_cost"     => {:grouping => [:total]},
      "fixed_compute_2_cost"     => {:grouping => [:total]},
      "fixed_cost"               => {:grouping => [:total]},
      "fixed_storage_1_cost"     => {:grouping => [:total]},
      "fixed_storage_2_cost"     => {:grouping => [:total]},
      "memory_allocated_cost"    => {:grouping => [:total]},
      "memory_allocated_metric"  => {:grouping => [:total]},
      "memory_cost"              => {:grouping => [:total]},
      "memory_metric"            => {:grouping => [:total]},
      "memory_used_cost"         => {:grouping => [:total]},
      "memory_used_metric"       => {:grouping => [:total]},
      "net_io_cost"              => {:grouping => [:total]},
      "net_io_metric"            => {:grouping => [:total]},
      "net_io_used_cost"         => {:grouping => [:total]},
      "net_io_used_metric"       => {:grouping => [:total]},
      "storage_allocated_cost"   => {:grouping => [:total]},
      "storage_allocated_metric" => {:grouping => [:total]},
      "storage_cost"             => {:grouping => [:total]},
      "storage_metric"           => {:grouping => [:total]},
      "storage_used_cost"        => {:grouping => [:total]},
      "storage_used_metric"      => {:grouping => [:total]},
      "total_cost"               => {:grouping => [:total]}
    }
  end
end # class Chargeback
