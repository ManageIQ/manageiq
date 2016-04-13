class ChargebackContainerProject < Chargeback
  set_columns_hash(
    :start_date           => :datetime,
    :end_date             => :datetime,
    :interval_name        => :string,
    :display_range        => :string,
    :project_name         => :string,
    :cpu_used_cost        => :float,
    :cpu_used_metric      => :float,
    :cpu_cost             => :float,
    :cpu_metric           => :float,
    :fixed_compute_1_cost => :float,
    :fixed_compute_2_cost => :float,
    :fixed_2_cost         => :float,
    :fixed_cost           => :float,
    :memory_used_cost     => :float,
    :memory_used_metric   => :float,
    :memory_cost          => :float,
    :memory_metric        => :float,
    :net_io_used_cost     => :float,
    :net_io_used_metric   => :float,
    :net_io_cost          => :float,
    :net_io_metric        => :float,
    :total_cost           => :float
  )

  def self.build_results_for_report_ChargebackContainerProject(options)
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
    #   :entity_id => 1/2/3.../all rails id of entity

    # Find Project by id or get all projects
    id = options[:entity_id]
    raise "must provide option :entity_id" if id.nil?

    @groups = if id == "all"
                ContainerGroup.all
              else
                ContainerGroup.where('container_project_id = ? or old_container_project_id = ?', id, id)
              end

    @groups = @groups.includes(:container_project, :old_container_project)
    return [[]] if @groups.empty?

    @data_index = {}
    @groups.each do |g|
      @data_index.store_path(:container_project, :by_group_id, g.id, g.container_project || g.old_container_project)
    end

    build_results_for_report_chargeback(options)
  end

  def self.get_keys_and_extra_fields(perf, ts_key)
    project = @data_index.fetch_path(:container_project, :by_group_id, perf.resource_id)
    key = "#{project.id}_#{ts_key}"

    [key, {"project_name"  => project.name}]
  end

  def self.where_clause(records, _options)
    records.where(:resource_type => ContainerGroup.name, :resource_id => @groups.pluck(:id))
  end

  def self.report_name_field
    "project_name"
  end

  def self.report_col_options
    {
      "cpu_cost"             => {:grouping => [:total]},
      "cpu_metric"           => {:grouping => [:total]},
      "cpu_used_cost"        => {:grouping => [:total]},
      "cpu_used_metric"      => {:grouping => [:total]},
      "fixed_compute_1_cost" => {:grouping => [:total]},
      "fixed_compute_2_cost" => {:grouping => [:total]},
      "fixed_cost"           => {:grouping => [:total]},
      "fixed_storage_1_cost" => {:grouping => [:total]},
      "fixed_storage_2_cost" => {:grouping => [:total]},
      "memory_cost"          => {:grouping => [:total]},
      "memory_metric"        => {:grouping => [:total]},
      "memory_used_cost"     => {:grouping => [:total]},
      "memory_used_metric"   => {:grouping => [:total]},
      "net_io_cost"          => {:grouping => [:total]},
      "net_io_metric"        => {:grouping => [:total]},
      "net_io_used_cost"     => {:grouping => [:total]},
      "net_io_used_metric"   => {:grouping => [:total]},
      "total_cost"           => {:grouping => [:total]}
    }
  end
end # class Chargeback
