class ChargebackVm < Chargeback
  set_columns_hash(
    :vm_id                    => :integer,
    :vm_name                  => :string,
    :vm_uid                   => :string,
    :vm_guid                  => :string,
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
    :fixed_compute_1_cost     => :float,
    :fixed_compute_2_cost     => :float,
    :fixed_storage_1_cost     => :float,
    :fixed_storage_2_cost     => :float,
    :memory_allocated_cost    => :float,
    :memory_allocated_metric  => :float,
    :memory_used_cost         => :float,
    :memory_used_metric       => :float,
    :memory_cost              => :float,
    :memory_metric            => :float,
    :net_io_used_cost         => :float,
    :net_io_used_metric       => :float,
    :storage_allocated_cost   => :float,
    :storage_allocated_metric => :float,
    :storage_used_cost        => :float,
    :storage_used_metric      => :float,
    :storage_cost             => :float,
    :storage_metric           => :float,
    :total_cost               => :float,
  )

  def self.build_results_for_report_ChargebackVm(options)
    # Options: a hash transformable to Chargeback::ReportOptions

    @report_user = User.find_by(:userid => options[:userid])

    @vm_owners = @vms = nil
    build_results_for_report_chargeback(options)
  end

  def self.where_clause(records, options)
    scope = records.where(:resource_type => "VmOrTemplate")
    if options[:tag] && (@report_user.nil? || !@report_user.self_service?)
      scope.for_tag_names(options[:tag].split("/")[2..-1])
    else
      scope.where(:resource => vms)
    end
  end

  def self.extra_resources_without_rollups
    # support hyper-v for which we do not collect metrics yet (also when we are including metrics in calculations)
    scope = @options.include_metrics? ? ManageIQ::Providers::Microsoft::InfraManager::Vm : vms
    scope = scope.eager_load(:hardware, :taggings, :tags, :host, :ems_cluster, :storage, :ext_management_system,
                             :tenant)

    if @options[:tag] && (@report_user.nil? || !@report_user.self_service?)
      scope.find_tagged_with(:any => @options[:tag], :ns => '*')
    else
      scope.where(:id => vms)
    end
  end

  def self.report_static_cols
    %w(vm_name)
  end

  def self.report_col_options
    {
      "cpu_allocated_cost"       => {:grouping => [:total]},
      "cpu_allocated_metric"     => {:grouping => [:total]},
      "cpu_cost"                 => {:grouping => [:total]},
      "cpu_metric"               => {:grouping => [:total]},
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
      "memory_metric"            => {:grouping => [:total]},
      "memory_used_cost"         => {:grouping => [:total]},
      "memory_used_metric"       => {:grouping => [:total]},
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

  def self.vm_owner(consumption)
    @vm_owners ||= vms.each_with_object({}) { |vm, res| res[vm.id] = vm.evm_owner_name }
    @vm_owners[consumption.resource_id] ||= consumption.resource.evm_owner_name
  end

  def self.vms
    @vms ||=
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
          if tenant.nil?
            _log.error("Unable to find tenant '#{@options[:tenant_id]}'. Calculating chargeback costs aborted.")
            raise MiqException::Error, "Unable to find tenant '#{@options[:tenant_id]}'"
          end
          tenant.vms
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

  private

  def init_extra_fields(consumption)
    self.vm_id         = consumption.resource_id
    self.vm_name       = consumption.resource_name
    self.vm_uid        = consumption.resource.ems_ref
    self.vm_guid       = consumption.resource.try(:guid)
    self.owner_name    = self.class.vm_owner(consumption)
    self.provider_name = consumption.parent_ems.try(:name)
    self.provider_uid  = consumption.parent_ems.try(:guid)
  end
end # class Chargeback
