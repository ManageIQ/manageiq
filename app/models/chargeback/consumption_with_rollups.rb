class Chargeback
  class ConsumptionWithRollups < Consumption
    delegate :timestamp, :resource, :resource_id, :resource_name, :resource_type, :parent_ems,
             :parents_determining_rate, :resource_current_tag_names,
             :to => :first_metric_rollup_record

    attr_accessor :start_time, :end_time

    def initialize(metric_rollup_records, start_time, end_time)
      super(start_time, end_time)
      @rollup_records = metric_rollup_records
    end

    def hash_features_affecting_rate
      @hash_features_affecting_rate ||= begin
        tags = tag_names.reject { |n| n.starts_with?('folder_path_') }.sort.join('|')
        keys = [tags] + first_metric_rollup_record.resource_parents.map(&:id)
        keys += [first_metric_rollup_record.resource.container_image, timestamp] if resource_type == Container.name
        keys.join('_')
      end
    end

    def tag_names
      @tag_names ||= rollup_records.inject([]) do |memo, rollup|
        memo |= all_tag_names(rollup)
        memo
      end
    end

    TAG_MANAGED_PREFIX = "/tag/managed/".freeze

    def tag_prefix
      klass_prefix = case resource_type
                     when Container.name        then 'container_image'
                     when ContainerImage.name   then 'container_image'
                     when VmOrTemplate.name     then 'vm'
                     when ContainerProject.name then 'container_project'
                     end

      klass_prefix + TAG_MANAGED_PREFIX
    end

    def chargeback_container_labels
      docker_labels.try(:collect_concat) do |l|
        escaped_name = AssignmentMixin.escape(l.name)
        escaped_value = AssignmentMixin.escape(l.value)
        [
          # The assignments in tags can appear the old way as they are, or escaped
          "container_image/label/managed/#{l.name}/#{l.value}",
          "container_image/label/managed/#{escaped_name}/#{escaped_value}"
        ]
      end || []
    end

    def container_tag_list_with_prefix
      if resource.kind_of?(ContainerImage)
        state = resource.vim_performance_state_for_ts(timestamp)
        image_tag_name = "#{state.image_tag_names}|" if state

        image_tag_name.split("|")
      else
        []
      end
    end

    def tag_list_with_prefix_for(rollup)
      (all_tag_names(rollup) + container_tag_list_with_prefix).uniq.reject(&:empty?).map { |x| "#{tag_prefix}#{x}" } + chargeback_container_labels
    end

    def tag_list_with_prefix
      @tag_list_with_prefix ||= rollup_records.map { |rollup| tag_list_with_prefix_for(rollup) }.flatten.uniq
    end

    def sum(metric, sub_metric = nil)
      values(metric, sub_metric).sum
    end

    def max(metric, sub_metric = nil)
      values = values(metric, sub_metric)
      values.present? ? values.max : 0
    end

    def sum_of_maxes_from_grouped_values(metric, sub_metric = nil)
      return max(metric, sub_metric) if sub_metric

      @grouped_values ||= {}
      grouped_rollups = rollup_records.group_by { |x| x[ChargeableField.col_index(:resource_id)] }

      @grouped_values[metric] ||= grouped_rollups.map do |_, rollups|
        rollups.map { |x| rollup_field(x, metric) }.compact.max
      end.compact.sum
    end

    def avg(metric, sub_metric = nil)
      metric_sum = values(metric, sub_metric).sum
      metric_sum / consumed_hours_in_interval
    end

    def current_value(metric, _sub_metric) # used for containers allocated metrics
      case metric
      when 'derived_vm_numvcpu_cores', 'derived_vm_numvcpus_cores' # Allocated CPU count
        resource.try(:limit_cpu_cores).to_f
      when 'derived_memory_available'
        resource.try(:limit_memory_bytes).to_f / 1.megabytes # bytes to megabytes
      end
    end

    def none?(metric, sub_metric)
      values(metric, sub_metric).empty?
    end

    def chargeback_fields_present
      @chargeback_fields_present ||= rollup_records.count { |rollup| chargeback_fields_present?(rollup) }
    end

    def chargeback_fields_present?(rollup_record)
      MetricRollup::CHARGEBACK_METRIC_FIELDS.any? do |field|
        rollup = rollup_field(rollup_record, field)
        rollup.present? && rollup.nonzero?
      end
    end

    def metering_used_fields_present?(rollup_record)
      MetricRollup::METERING_USED_METRIC_FIELDS.any? do |field|
        rollup = rollup_field(rollup_record, field)
        rollup.present? && rollup.nonzero?
      end
    end

    def metering_used_fields_present
      @metering_used_fields_present ||= rollup_records.count { |rollup| metering_used_fields_present?(rollup) }
    end

    def metering_allocated_for(metric)
      @metering_allocated_metric ||= {}
      @metering_allocated_metric[metric] ||= rollup_records.count do |rollup|
        rollup_record = rollup_field(rollup, metric)
        rollup_record.present? && rollup_record.nonzero?
      end
    end

    def resource_tag_names(rollup)
      tags_names = rollup[ChargeableField.col_index(:tag_names)]
      tags_names ? tags_names.split('|') : []
    end

    def all_tag_names(rollup)
      resource_current_tag_names | resource_tag_names(rollup)
    end

    def tag_filter_for_rollup_records(tag)
      @tag_filter_for_rollup_records = tag
    end

    private

    def docker_labels
      resource.try(:docker_labels) || resource.try(:container_image).try(:docker_labels)
    end

    def born_at
      # metrics can be older than resource (first capture may go few days back)
      [super, first_metric_rollup_record.timestamp].compact.min
    end

    def sub_metric_rollups(sub_metric)
      q = VimPerformanceState.where(:timestamp => start_time...end_time, :resource => resource, :capture_interval => 3_600)
      q.map { |x| x.state_data.try(:[], :allocated_disk_types).try(:[], sub_metric) || 0 }
    end

    def values(metric, sub_metric = nil)
      @values ||= {}
      @values["#{metric}#{sub_metric}"] ||= begin
        sub_metric ? sub_metric_rollups(sub_metric) : rollup_records.collect { |x| rollup_field(x, metric) }.compact
      end
    end

    def rollup_field(rollup, metric)
      if metric == "v_derived_cpu_total_cores_used"
        return v_derived_cpu_total_cores_used_for(rollup)
      end

      if metric == "derived_vm_numvcpu_cores"
        return rollup[ChargeableField.col_index('derived_vm_numvcpus')]
      end

      rollup[ChargeableField.col_index(metric)]
    end

    def v_derived_cpu_total_cores_used_for(rollup)
      cpu_usage_rate_average = rollup[ChargeableField.col_index("cpu_usage_rate_average")]
      derived_vm_numvcpus    = rollup[ChargeableField.col_index("derived_vm_numvcpus")]

      return nil if cpu_usage_rate_average.nil? || derived_vm_numvcpus.nil? || derived_vm_numvcpus == 0

      (cpu_usage_rate_average * derived_vm_numvcpus) / 100.0
    end

    def first_metric_rollup_record
      first_rollup_id = @rollup_records.first[ChargeableField.col_index(:id)]
      @fmrr ||= MetricRollup.find(first_rollup_id) if first_rollup_id
    end

    def tag_name_filter
      return nil unless @tag_filter_for_rollup_records

      @tag_filter_for_rollup_records.name.split("/").last(2).join("/")
    end

    def rollup_records_tagged_partially?
      tag_name_filter && tag_filtered_for_rollup_records.present? && tag_filtered_for_rollup_records.count != @rollup_records.count
    end

    def current_resource_tags_in_tag_filter?
      (resource_current_tag_names & [tag_name_filter]).present?
    end

    def rollup_records
      if rollup_records_tagged_partially? && !current_resource_tags_in_tag_filter?
        tag_filtered_for_rollup_records
      else
        @rollup_records
      end
    end

    def tag_filtered_for_rollup_records
      return @rollup_records unless tag_name_filter

      @tag_filtered_for_rollup_records ||= {}
      @tag_filtered_for_rollup_records[tag_name_filter] ||= begin
        @rollup_records.select do |rollup|
          (resource_tag_names(rollup) & [tag_name_filter]).present?
        end
      end
    end
  end
end
