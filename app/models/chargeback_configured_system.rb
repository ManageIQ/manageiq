class ChargebackConfiguredSystem < Chargeback
  set_columns_hash(
    :configured_system_id    => :integer,
    :configured_system_name  => :string,
    :configured_system_uid   => :string,
    :configured_system_guid  => :string,
    :provider_name           => :string,
    :tenant_name             => :string,
    :provider_uid            => :string,
    :cpu_allocated_metric    => :float,
    :cpu_allocated_cost      => :float,
    :cpu_cost                => :float,
    :fixed_compute_1_cost    => :float,
    :fixed_compute_2_cost    => :float,
    :memory_allocated_cost   => :float,
    :memory_allocated_metric => :float,
    :memory_cost             => :float,
    :total_cost              => :float
  )

  def self.build_results_for_report_ChargebackConfiguredSystem(options)
    @report_user = User.find_by(:userid => options[:userid])

    @configured_systems = nil
    build_results_for_report_chargeback(options)
  end

  def self.where_clause(records, options, region)
    scope = records.where(:resource_type => "ConfiguredSystem")
    if options[:tag] && (@report_user.nil? || !@report_user.self_service?)
      scope_with_current_tags = scope.where(:resource => ConfiguredSystem.find_tagged_with(:any => @options[:tag], :ns => '*'))
      scope.for_tag_names(Array(options[:tag]).flatten.map { |t| t.split("/")[2..-1] }).or(scope_with_current_tags)
    else
      scope.where(:resource => configured_systems(region))
    end
  end

  def self.extra_resources_without_rollups(region)
    scope = ConfiguredSystem.eager_load(:hardware, :taggings, :tags)

    if @options[:tag] && (@report_user.nil? || !@report_user.self_service?)
      scope.find_tagged_with(:any => @options[:tag], :ns => '*')
    else
      scope.where(:id => configured_systems(region))
    end
  end

  def self.report_static_cols
    %w[configured_system_name]
  end

  def self.report_col_options
    {
      "cpu_allocated_cost"      => {:grouping => [:total]},
      "cpu_allocated_metric"    => {:grouping => [:total]},
      "cpu_cost"                => {:grouping => [:total]},
      "fixed_compute_metric"    => {:grouping => [:total]},
      "fixed_compute_1_cost"    => {:grouping => [:total]},
      "fixed_compute_2_cost"    => {:grouping => [:total]},
      "fixed_cost"              => {:grouping => [:total]},
      "memory_allocated_cost"   => {:grouping => [:total]},
      "memory_allocated_metric" => {:grouping => [:total]},
      "memory_cost"             => {:grouping => [:total]},
      "total_cost"              => {:grouping => [:total]}
    }
  end

  def self.configured_systems(region)
    @configured_systems ||= {}
    @configured_systems[region] ||=
      begin
        if @options[:entity_id]
          ConfiguredSystem.where(:id => @options[:entity_id])
        elsif @options[:tag]
          ConfiguredSystem.find_tagged_with(:all => @options[:tag], :ns => '*')
        else
          raise _('Unable to find strategy for Configured Systems selection')
        end
      end
  end

  def self.display_name(number = 1)
    n_('Chargeback for Configured Systems', 'Chargebacks for Configured Systems', number)
  end

  private

  def init_extra_fields(consumption, _region)
    self.configured_system_id   = consumption.resource_id
    self.configured_system_name = consumption.resource_name
    self.configured_system_uid  = consumption.resource.try(:manager_ref)
    self.configured_system_guid = consumption.resource.try(:virtual_instance_ref)
    self.provider_name          = consumption.parent_ems.try(:name)
    self.provider_uid           = consumption.parent_ems.try(:guid)
  end
end
