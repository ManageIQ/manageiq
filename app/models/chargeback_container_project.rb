class ChargebackContainerProject < Chargeback
  set_columns_hash(
    :project_name          => :string,
    :project_uid           => :string,
    :provider_name         => :string,
    :provider_uid          => :string,
    :archived              => :string,
    :cpu_cores_used_cost   => :float,
    :cpu_cores_used_metric => :float,
    :fixed_compute_1_cost  => :float,
    :fixed_compute_2_cost  => :float,
    :fixed_2_cost          => :float,
    :fixed_cost            => :float,
    :memory_used_cost      => :float,
    :memory_used_metric    => :float,
    :net_io_used_cost      => :float,
    :net_io_used_metric    => :float,
    :total_cost            => :float,
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
                  ContainerProject.where(:ems_id => provider_id)
                elsif project_id.present?
                  ContainerProject.where(:id => project_id)
                elsif project_id.nil? && provider_id.nil? && filter_tag.nil?
                  raise "must provide option :entity_id, provider_id or tag"
                end

    return [[]] if @projects.empty?

    build_results_for_report_chargeback(options)
  ensure
    @projects = nil
  end

  def self.where_clause(records, _options, region)
    records.where(:resource_type => ContainerProject.name, :resource_id => @projects.in_region(region).select(:id))
  end

  def self.report_static_cols
    %w(project_name)
  end

  def self.report_col_options
    {
      "cpu_cores_used_cost"   => {:grouping => [:total]},
      "cpu_cores_used_metric" => {:grouping => [:total]},
      "fixed_compute_metric"  => {:grouping => [:total]},
      "fixed_compute_1_cost"  => {:grouping => [:total]},
      "fixed_compute_2_cost"  => {:grouping => [:total]},
      "fixed_cost"            => {:grouping => [:total]},
      "memory_used_cost"      => {:grouping => [:total]},
      "memory_used_metric"    => {:grouping => [:total]},
      "net_io_used_cost"      => {:grouping => [:total]},
      "net_io_used_metric"    => {:grouping => [:total]},
      "total_cost"            => {:grouping => [:total]}
    }
  end

  def self.display_name(number = 1)
    n_('Chargeback for Projects', 'Chargebacks for Projects', number)
  end

  private

  def init_extra_fields(consumption, _region)
    self.project_name  = consumption.resource_name
    self.project_uid   = consumption.resource.ems_ref
    self.provider_name = consumption.parent_ems.try(:name)
    self.provider_uid  = consumption.parent_ems.try(:guid)
    self.archived      = consumption.resource.archived? ? _('Yes') : _('No')
  end
end # class Chargeback
