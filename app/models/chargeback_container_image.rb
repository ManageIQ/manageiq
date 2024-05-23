class ChargebackContainerImage < Chargeback
  set_columns_hash(
    :project_name               => :string,
    :image_name                 => :string,
    :project_uid                => :string,
    :provider_name              => :string,
    :provider_uid               => :string,
    :archived                   => :string,
    :cpu_cores_used_cost        => :float,
    :cpu_cores_used_metric      => :float,
    :cpu_cores_allocated_metric => :float,
    :cpu_cores_allocated_cost   => :float,
    :fixed_compute_1_cost       => :float,
    :fixed_compute_2_cost       => :float,
    :fixed_cost                 => :float,
    :memory_used_cost           => :float,
    :memory_used_metric         => :float,
    :memory_allocated_cost      => :float,
    :memory_allocated_metric    => :float,
    :net_io_used_cost           => :float,
    :net_io_used_metric         => :float,
    :total_cost                 => :float
  )

  def self.build_results_for_report_ChargebackContainerImage(options)
    # Options: a hash transformable to Chargeback::ReportOptions

    # Find Project by id or get all projects
    provider_id = options[:provider_id]
    id = options[:entity_id]

    tag = options[:tag]
    raise "must provide option :entity_id, provider_id or tag" if id.nil? && provider_id.nil? && tag.nil?

    @container_images = if tag
                          ContainerImage.find_tagged_with(:any => tag, :ns => '*')
                        elsif provider_id == "all"
                          ContainerImage.all
                        elsif id == "all"
                          ContainerImage.where(:ems_id => provider_id)
                        else
                          ContainerImage.where(:id => id)
                        end

    @container_images = @container_images.includes(:container_projects)
    return [[]] if @container_images.empty?

    @data_index = {}
    @container_images.each do |container_image|
      @data_index.store_path(:id, :container_projects, container_image.id, container_image.container_projects)
    end

    @unknown_project = OpenStruct.new(:id => 0, :name => _('Unknown Project'), :ems_ref => _('Unknown'))
    @unknown_image   = OpenStruct.new(:id => 0, :full_name => _('Unknown Image'))

    load_custom_attribute_groupby(options[:groupby_label]) if options[:groupby_label].present?

    build_results_for_report_chargeback(options)
  ensure
    @data_index = @container_images = nil
  end

  def self.load_custom_attribute_groupby(groupby_label)
    report_cb_model(name).safe_constantize.add_custom_attribute(groupby_label_method(groupby_label))
  end

  def self.groupby_label_method(groupby_label)
    CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX + groupby_label + CustomAttributeMixin::SECTION_SEPARATOR + 'docker_labels'
  end

  def self.groupby_label_value(consumption, groupby_label)
    ChargebackContainerImage.image(consumption).try(groupby_label_method(groupby_label))
  end

  def self.default_key(metric_rollup_record, ts_key)
    project_ids = project(metric_rollup_record)
    project_id = project_ids.first.id
    image = self.image(metric_rollup_record)
    @options[:groupby] == 'project' ? "#{project_id}_#{ts_key}" : "#{project_id}_#{image.id}_#{ts_key}"
  end

  def self.image(consumption)
    consumption.resource || @unknown_image
  end

  def self.project(consumption)
    @data_index.fetch_path(:id, :container_projects, consumption.resource_id) || @unknown_project
  end

  def self.where_clause(records, _options, region)
    records.where(:resource => @container_images.in_region(region))
  end

  def self.report_static_cols
    %w[project_name image_name]
  end

  def self.report_col_options
    {
      "cpu_cores_used_cost"        => {:grouping => [:total]},
      "cpu_cores_used_metric"      => {:grouping => [:total]},
      "cpu_cores_allocated_metric" => {:grouping => [:total]},
      "cpu_cores_allocated_cost"   => {:grouping => [:total]},
      "fixed_compute_metric"       => {:grouping => [:total]},
      "fixed_compute_1_cost"       => {:grouping => [:total]},
      "fixed_compute_2_cost"       => {:grouping => [:total]},
      "fixed_cost"                 => {:grouping => [:total]},
      "memory_used_cost"           => {:grouping => [:total]},
      "memory_used_metric"         => {:grouping => [:total]},
      "memory_allocated_cost"      => {:grouping => [:total]},
      "memory_allocated_metric"    => {:grouping => [:total]},
      "net_io_used_cost"           => {:grouping => [:total]},
      "net_io_used_metric"         => {:grouping => [:total]},
      "total_cost"                 => {:grouping => [:total]}
    }
  end

  def self.display_name(number = 1)
    n_('Chargeback for Image', 'Chargebacks for Image', number)
  end

  private

  def init_extra_fields(consumption, _region)
    self.project_name  = self.class.project(consumption).map(&:name).join(",")
    self.image_name    = self.class.image(consumption).try(:full_name)
    self.project_uid   = self.class.project(consumption).map(&:ems_ref).join(",")
    self.provider_name = consumption.parent_ems.try(:name)
    self.provider_uid  = consumption.parent_ems.try(:guid)
    self.archived      = self.class.project(consumption).map { |x| x.archived? ? _('Yes') : _('No') }
    self.entity        = self.class.image(consumption)
  end
end # class ChargebackContainerImage
