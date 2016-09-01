class ChargebackContainerProject < Chargeback
  set_columns_hash(
    :start_date            => :datetime,
    :end_date              => :datetime,
    :interval_name         => :string,
    :display_range         => :string,
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
    :net_io_cost           => :float,
    :net_io_metric         => :float,
    :total_cost            => :float
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

    # Find ContainerProjects according to any of these:
    provider_id = options[:provider_id]
    project_id = options[:entity_id]
    tag = options[:tag]

    @project_ids = if tag.present?
                     # Get all ids of tagged projects
                     ContainerProject.find_tagged_with(:all => tag, :ns => "*").pluck(:id)
                   elsif provider_id == "all"
                     ContainerProject.all.pluck(:id)
                   elsif provider_id.present? && project_id == "all"
                     ContainerProject.where('ems_id = ? or old_ems_id = ?', provider_id, provider_id).pluck(:id)
                   elsif project_id.present?
                     [project_id.to_i]
                   elsif project_id.nil? && provider_id.nil? && tag.nil?
                     raise "must provide option :entity_id, provider_id or tag"
                   end

    return [[]] if @project_ids.empty?

    build_results_for_report_chargeback(options)
  end

  def self.get_keys_and_extra_fields(perf, ts_key)
    key = "#{perf.resource_id}_#{ts_key}"
    extra_fields = {
      "project_name"  => perf.resource_name,
      "project_uid"   => perf.resource.ems_ref,
      "provider_name" => perf.parent_ems.try(:name),
      "provider_uid"  => perf.parent_ems.try(:guid),
      "archived"      => perf.resource.archived? ? _("Yes") : _("No")
    }

    [key, extra_fields]
  end

  def self.where_clause(records, _options)
    records.where(:resource_type => ContainerProject.name, :resource_id => @project_ids)
  end

  def self.report_name_field
    "project_name"
  end

  def self.report_col_options
    {
      "cpu_cores_used_cost"   => {:grouping => [:total]},
      "cpu_cores_used_metric" => {:grouping => [:total]},
      "fixed_compute_1_cost"  => {:grouping => [:total]},
      "fixed_compute_2_cost"  => {:grouping => [:total]},
      "fixed_cost"            => {:grouping => [:total]},
      "memory_used_cost"      => {:grouping => [:total]},
      "memory_used_metric"    => {:grouping => [:total]},
      "net_io_cost"           => {:grouping => [:total]},
      "net_io_metric"         => {:grouping => [:total]},
      "net_io_used_cost"      => {:grouping => [:total]},
      "net_io_used_metric"    => {:grouping => [:total]},
      "total_cost"            => {:grouping => [:total]}
    }
  end
end # class Chargeback
