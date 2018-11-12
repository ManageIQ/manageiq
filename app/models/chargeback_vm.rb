class ChargebackVm < Chargeback
  set_columns_hash(
    :vm_id                    => :integer,
    :vm_name                  => :string,
    :vm_uid                   => :string,
    :vm_guid                  => :string,
    :owner_name               => :string,
    :provider_name            => :string,
    :tenant_name              => :string,
    :provider_uid             => :string,
    :cpu_allocated_metric     => :float,
    :cpu_allocated_cost       => :float,
    :cpu_used_cost            => :float,
    :cpu_used_metric          => :float,
    :cpu_cost                 => :float,
    :disk_io_used_cost        => :float,
    :disk_io_used_metric      => :float,
    :fixed_compute_1_cost     => :float,
    :fixed_compute_2_cost     => :float,
    :fixed_storage_1_cost     => :float,
    :fixed_storage_2_cost     => :float,
    :memory_allocated_cost    => :float,
    :memory_allocated_metric  => :float,
    :memory_used_cost         => :float,
    :memory_used_metric       => :float,
    :memory_cost              => :float,
    :net_io_used_cost         => :float,
    :net_io_used_metric       => :float,
    :storage_allocated_cost   => :float,
    :storage_allocated_metric => :float,
    :storage_used_cost        => :float,
    :storage_used_metric      => :float,
    :storage_cost             => :float,
    :total_cost               => :float,
  )

  DEFAULT_STORAGE_METRICS = %w(
    storage_allocated_unclassified_metric
    storage_allocated_unclassified_cost
    storage_allocated_metric
    storage_allocated_cost
  ).freeze

  cache_with_timeout(:current_volume_types) do
    volume_types = CloudVolume.volume_types
    volume_types.push(nil) if volume_types.present?
    volume_types
  end

  def self.attribute_names
    loaded_attribute_names = super
    loaded_storage_allocated_attributes = loaded_attribute_names.select { |x| x.starts_with?('storage_allocated_') }
    loaded_sub_metric_fields            = loaded_storage_allocated_attributes - DEFAULT_STORAGE_METRICS
    non_existing_sub_metric_fields      = loaded_sub_metric_fields - dynamic_columns_for(:float).keys - dynamic_rate_columns.keys

    loaded_attribute_names - non_existing_sub_metric_fields
  end

  # example:
  #  dynamic_columns_for(:group => [:total])
  #  returns:
  # { 'storage_allocated_volume_type1_metric' => {:group => [:total]},
  #   'storage_allocated_volume_type1_cost'   => {:group => [:total]},
  # }
  def self.dynamic_columns_for(column_type)
    current_volume_types.each_with_object({}) do |volume_type, result|
      %i(metric cost rate).collect do |type|
        result["storage_allocated_#{volume_type || 'unclassified'}_#{type}"] = column_type
      end
    end
  end

  def self.refresh_dynamic_metric_columns
    set_columns_hash(dynamic_columns_for(:float))
    super
  end

  def self.build_results_for_report_ChargebackVm(options)
    # Options: a hash transformable to Chargeback::ReportOptions

    # Get the most up to date types from the DB
    current_volume_types(true)

    @report_user = User.find_by(:userid => options[:userid])

    @vm_owners = @vms = nil
    build_results_for_report_chargeback(options)
  end

  def self.where_clause(records, options, region)
    scope = records.where(:resource_type => "VmOrTemplate")
    if options[:tag] && (@report_user.nil? || !@report_user.self_service?)
      scope_with_current_tags = scope.where(:resource => Vm.find_tagged_with(:any => @options[:tag], :ns => '*'))
      scope.for_tag_names(options[:tag].split("/")[2..-1]).or(scope_with_current_tags)
    else
      scope.where(:resource => vms(region))
    end
  end

  def self.extra_resources_without_rollups(region)
    # support hyper-v for which we do not collect metrics yet (also when we are including metrics in calculations)
    scope = @options.include_metrics? ? ManageIQ::Providers::Microsoft::InfraManager::Vm : vms(region)
    scope = scope.eager_load(:hardware, :taggings, :tags, :host, :ems_cluster, :storage, :ext_management_system,
                             :tenant)

    if @options[:tag] && (@report_user.nil? || !@report_user.self_service?)
      scope.find_tagged_with(:any => @options[:tag], :ns => '*')
    else
      scope.where(:id => vms(region))
    end
  end

  def self.report_static_cols
    %w(vm_name)
  end

  def self.sub_metric_columns
    dynamic_columns_for(:grouping => [:total])
  end

  def self.report_col_options
    {
      "cpu_allocated_cost"       => {:grouping => [:total]},
      "cpu_allocated_metric"     => {:grouping => [:total]},
      "cpu_cost"                 => {:grouping => [:total]},
      "cpu_used_cost"            => {:grouping => [:total]},
      "cpu_used_metric"          => {:grouping => [:total]},
      "disk_io_used_cost"        => {:grouping => [:total]},
      "disk_io_used_metric"      => {:grouping => [:total]},
      "fixed_compute_metric"     => {:grouping => [:total]},
      "fixed_compute_1_cost"     => {:grouping => [:total]},
      "fixed_compute_2_cost"     => {:grouping => [:total]},
      "fixed_cost"               => {:grouping => [:total]},
      "fixed_storage_1_cost"     => {:grouping => [:total]},
      "fixed_storage_2_cost"     => {:grouping => [:total]},
      "memory_allocated_cost"    => {:grouping => [:total]},
      "memory_allocated_metric"  => {:grouping => [:total]},
      "memory_cost"              => {:grouping => [:total]},
      "memory_used_cost"         => {:grouping => [:total]},
      "memory_used_metric"       => {:grouping => [:total]},
      "net_io_used_cost"         => {:grouping => [:total]},
      "net_io_used_metric"       => {:grouping => [:total]},
      "storage_allocated_cost"   => {:grouping => [:total]},
      "storage_allocated_metric" => {:grouping => [:total]},
      "storage_cost"             => {:grouping => [:total]},
      "storage_used_cost"        => {:grouping => [:total]},
      "storage_used_metric"      => {:grouping => [:total]},
      "total_cost"               => {:grouping => [:total]}
    }.merge(sub_metric_columns)
  end

  def self.vm_owner(consumption, region)
    @vm_owners ||= vms(region).each_with_object({}) { |vm, res| res[vm.id] = vm.evm_owner_name }
    @vm_owners[consumption.resource_id] ||= consumption.resource.try(:evm_owner_name)
  end

  def self.vms(region)
    @vms ||= {}
    @vms[region] ||=
      begin
        # Find Vms by user or by tag
        if @options[:entity_id]
          Vm.where(:id => @options[:entity_id])
        elsif @options[:owner]
          user = User.find_by_userid(@options[:owner])
          if user.nil?
            _log.error("Unable to find user '#{@options[:owner]}'. Calculating chargeback costs aborted.")
            raise MiqException::Error, _("Unable to find user '%{name}'") % {:name => @options[:owner]}
          end
          user.vms
        elsif @options[:tag]
          vms = Vm.find_tagged_with(:all => @options[:tag], :ns => '*')
          vms &= @report_user.accessible_vms if @report_user && @report_user.self_service?
          vms
        elsif @options[:tenant_id]
          tenant = Tenant.find(@options[:tenant_id])
          tenant = Tenant.in_region(region).find_by(:name => tenant.name)
          if tenant.nil?
            _log.error("Unable to find tenant '#{@options[:tenant_id]}'. Calculating chargeback costs aborted.")
            raise MiqException::Error, "Unable to find tenant '#{@options[:tenant_id]}'"
          end
          Vm.where(:id => tenant.subtree.map { |t| t.vms.ids }.flatten)
        elsif @options[:service_id]
          service = Service.find(@options[:service_id])
          if service.nil?
            _log.error("Unable to find service '#{@options[:service_id]}'. Calculating chargeback costs aborted.")
            raise MiqException::Error, "Unable to find service '#{@options[:service_id]}'"
          end
          service.vms
        else
          raise _('Unable to find strategy for VM selection')
        end
      end
  end

  def self.display_name(number = 1)
    n_('Chargeback for VMs', 'Chargebacks for VMs', number)
  end

  private

  def init_extra_fields(consumption, region)
    self.vm_id         = consumption.resource_id
    self.vm_name       = consumption.resource_name
    self.vm_uid        = consumption.resource.try(:ems_ref)
    self.vm_guid       = consumption.resource.try(:guid)
    self.owner_name    = self.class.vm_owner(consumption, region)
    self.provider_name = consumption.parent_ems.try(:name)
    self.provider_uid  = consumption.parent_ems.try(:guid)
  end
end # class Chargeback
