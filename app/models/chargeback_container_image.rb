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

    @containers = @containers.includes(:container_project, :old_container_project, :container_image, :container_groups)
    return [[]] if @containers.empty?

    @data_index = {}
    @containers.each do |c|
      @data_index.store_path(:container_project, :by_container_id, c.id, c.container_project || c.old_container_project)
      @data_index.store_path(:container_image, :by_container_id, c.id, c.container_image)
    end

    @unknown_project ||= OpenStruct.new(:id => 0, :name => _('Unknown Project'), :ems_ref => _('Unknown'))
    @unknown_image ||= OpenStruct.new(:id => 0, :full_name => _('Unknown Image'))
    build_results_for_report_chargeback(options)
  ensure
    @data_index = @containers = nil
  end

  def self.default_key(metric_rollup_record, ts_key)
    project = self.project(metric_rollup_record)
    image = self.image(metric_rollup_record)
    @options[:groupby] == 'project' ? "#{project.id}_#{ts_key}" : "#{project.id}_#{image.id}_#{ts_key}"
  end

  def self.image(consumption)
    @data_index.fetch_path(:container_image, :by_container_id, consumption.resource_id) || @unknown_image
  end

  def self.project(consumption)
    @data_index.fetch_path(:container_project, :by_container_id, consumption.resource_id) || @unknown_project
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

  def init_extra_fields(consumption)
    self.project_name  = self.class.project(consumption).name
    self.image_name    = self.class.image(consumption).try(:full_name)
    self.project_uid   = self.class.project(consumption).ems_ref
    self.provider_name = consumption.parent_ems.try(:name)
    self.provider_uid  = consumption.parent_ems.try(:guid)
    self.archived      = self.class.project(consumption).archived? ? _('Yes') : _('No')
    self.entity        = self.class.image(consumption)
  end
end # class ChargebackContainerImage
