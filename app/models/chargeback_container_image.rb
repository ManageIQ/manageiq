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

  def self.get_keys_and_extra_fields(perf, ts_key)
    project = @data_index.fetch_path(:container_project, :by_container_id, perf.resource_id)
    image = @data_index.fetch_path(:container_image, :by_container_id, perf.resource_id)

    key = @options[:groupby] == 'project' ? "#{project.id}_#{ts_key}" : "#{project.id}_#{image.id}_#{ts_key}"

    extra_fields = {
      "project_name"  => project.name,
      "image_name"    => image.try(:full_name) || _("Deleted"), # until image archiving is implemented
      "project_uid"   => project.ems_ref,
      "provider_name" => perf.parent_ems.try(:name),
      "provider_uid"  => perf.parent_ems.try(:name),
      "archived"      => project.archived? ? _("Yes") : _("No"),
      "entity"        => image
    }

    [key, extra_fields]
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

  def get_rate_parents(_perf)
    # get rates from image tags only
    []
  end
end # class ChargebackContainerImage
