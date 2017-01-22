class ChargebackContainerProject < Chargeback
  set_columns_hash(
    :project_name                        => :string,
    :project_uid                         => :string,
    :provider_name                       => :string,
    :provider_uid                        => :string,
    :archived                            => :string,
    :cpu_cores_used_cost                 => :float,
    :cpu_cores_used_metric               => :float,
    :fixed_compute_1_cost                => :float,
    :fixed_compute_2_cost                => :float,
    :fixed_2_cost                        => :float,
    :fixed_cost                          => :float,
    :memory_used_cost                    => :float,
    :memory_used_metric                  => :float,
    :net_io_used_cost                    => :float,
    :net_io_used_metric                  => :float,
    :quota_cpu_cost                      => :float,
    :quota_cpu_metric                    => :float,
    :quota_memory_cost                   => :float,
    :quota_memory_metric                 => :float,
    :quota_pods_cost                     => :float,
    :quota_pods_metric                   => :float,
    :quota_replicationcontrollers_cost   => :float,
    :quota_replicationcontrollers_metric => :float,
    :quota_resourcequotas_cost           => :float,
    :quota_resourcequotas_metric         => :float,
    :quota_services_cost                 => :float,
    :quota_services_metric               => :float,
    :quota_secrets_cost                  => :float,
    :quota_secrets_metric                => :float,
    :quota_persistentvolumeclaims_cost   => :float,
    :quota_persistentvolumeclaims_metric => :float,
    :quota_cost                          => :float,
    :total_cost                          => :float,
  )

  def self.build_results_for_report_ChargebackContainerProject(options)
    # Options: a hash transformable to Chargeback::ReportOptions

    # Find ContainerProjects according to any of these:
    provider_id = options[:provider_id]
    project_id = options[:entity_id]
    filter_tag = options[:tag]

    @projects = if filter_tag.present?
                  # Get all ids of tagged projects
                  ContainerProject.find_tagged_with(:all => filter_tag, :ns => "*")
                elsif provider_id == "all"
                  ContainerProject.all
                elsif provider_id.present? && project_id == "all"
                  ContainerProject.where('ems_id = ? or old_ems_id = ?', provider_id, provider_id)
                elsif project_id.present?
                  ContainerProject.where(:id => project_id)
                elsif project_id.nil? && provider_id.nil? && filter_tag.nil?
                  raise "must provide option :entity_id, provider_id or tag"
                end

    return [[]] if @projects.empty?

    build_results_for_report_chargeback(options)
  end

  def self.where_clause(records, _options)
    records.where(:resource_type => ContainerProject.name, :resource_id => @projects.select(:id))
  end

  def self.report_static_cols
    %w(project_name)
  end

  def self.report_col_options
    {
      "cpu_cores_used_cost"                 => {:grouping => [:total]},
      "cpu_cores_used_metric"               => {:grouping => [:total]},
      "fixed_compute_metric"                => {:grouping => [:total]},
      "fixed_compute_1_cost"                => {:grouping => [:total]},
      "fixed_compute_2_cost"                => {:grouping => [:total]},
      "fixed_cost"                          => {:grouping => [:total]},
      "memory_used_cost"                    => {:grouping => [:total]},
      "memory_used_metric"                  => {:grouping => [:total]},
      "net_io_used_cost"                    => {:grouping => [:total]},
      "net_io_used_metric"                  => {:grouping => [:total]},
      "quota_cpu_cost"                      => {:grouping => [:total]},
      "quota_cpu_metric"                    => {:grouping => [:total]},
      "quota_memory_cost"                   => {:grouping => [:total]},
      "quota_memory_metric"                 => {:grouping => [:total]},
      "quota_pods_cost"                     => {:grouping => [:total]},
      "quota_pods_metric"                   => {:grouping => [:total]},
      "quota_replicationcontrollers_cost"   => {:grouping => [:total]},
      "quota_replicationcontrollers_metric" => {:grouping => [:total]},
      "quota_resourcequotas_cost"           => {:grouping => [:total]},
      "quota_resourcequotas_metric"         => {:grouping => [:total]},
      "quota_services_cost"                 => {:grouping => [:total]},
      "quota_services_metric"               => {:grouping => [:total]},
      "quota_secrets_cost"                  => {:grouping => [:total]},
      "quota_secrets_metric"                => {:grouping => [:total]},
      "quota_persistentvolumeclaims_cost"   => {:grouping => [:total]},
      "quota_persistentvolumeclaims_metric" => {:grouping => [:total]},
      "quota_cost"                          => {:grouping => [:total]},
      "total_cost"                          => {:grouping => [:total]}
    }
  end

  private

  def init_extra_fields(consumption)
    self.project_name  = consumption.resource_name
    self.project_uid   = consumption.resource.ems_ref
    self.provider_name = consumption.parent_ems.try(:name)
    self.provider_uid  = consumption.parent_ems.try(:guid)
    self.archived      = consumption.resource.archived? ? _('Yes') : _('No')
  end
end # class Chargeback
