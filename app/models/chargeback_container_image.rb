class ChargebackContainerImage < Chargeback
  set_columns_hash(
    :project_name          => :string,
    :image_name            => :string,
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

  def self.build_results_for_report_ChargebackContainerImage(options)
    # Options: a hash transformable to Chargeback::ReportOptions

    # Find Project by id or get all projects
    provider_id = options[:provider_id]
    id = options[:entity_id]
    raise "must provide option :entity_id and provider_id" if id.nil? && provider_id.nil?

    @containers = if provider_id == "all"
                    Container.all
                  elsif id == "all"
                    Container.where('ems_id = ? or old_ems_id = ?', provider_id, provider_id)
                  else
                    Container.joins(:container_group).where('container_groups.container_project_id = ? or container_groups.old_container_project_id = ?', id, id)
                  end

    @containers = @containers.includes(:container_project, :old_container_project, :container_image)
    return [[]] if @containers.empty?

    @data_index = {}
    @containers.each do |c|
      @data_index.store_path(:container_project, :by_container_id, c.id, c.container_project || c.old_container_project)
      @data_index.store_path(:container_image, :by_container_id, c.id, c.container_image)
    end

    build_results_for_report_chargeback(options)
  end

  def self.default_key(metric_rollup_record, ts_key)
    project = @data_index.fetch_path(:container_project, :by_container_id, metric_rollup_record.resource_id)
    image = @data_index.fetch_path(:container_image, :by_container_id, metric_rollup_record.resource_id)
    @options[:groupby] == 'project' ? "#{project.id}_#{ts_key}" : "#{project.id}_#{image.id}_#{ts_key}"
  end

  def self.image(perf)
    @data_index.fetch_path(:container_image, :by_container_id, perf.resource_id)
  end

  def self.project(perf)
    @data_index.fetch_path(:container_project, :by_container_id, perf.resource_id)
  end

  def self.where_clause(records, _options)
    records.where(:resource_type => Container.name, :resource_id => @containers.pluck(:id))
  end

  def self.report_static_cols
    %w(project_name image_name)
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

  private

  def init_extra_fields(perf)
    self.project_name  = self.class.project(perf).name
    self.image_name    = self.class.image(perf).try(:full_name) || _('Deleted') # until image archiving is implemented
    self.project_uid   = self.class.project(perf).ems_ref
    self.provider_name = perf.parent_ems.try(:name)
    self.provider_uid  = perf.parent_ems.try(:name)
    self.archived      = self.class.project(perf).archived? ? _('Yes') : _('No'),
    self.entity        = self.class.image(perf)
  end
end # class ChargebackContainerImage
