class Chargeback
  class ConsumptionWithRollups < Consumption
    delegate :timestamp, :resource, :resource_id, :resource_name, :resource_type, :parent_ems,
             :parents_determining_rate, :resource_current_tag_names,
             :to => :first_metric_rollup_record

    attr_accessor :start_time, :end_time

    def initialize(metric_rollup_records, start_time, end_time)
      super(start_time, end_time)
      @rollup_array = metric_rollup_records
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
      @tag_names ||= @rollup_array.inject([]) do |memo, rollup|
        memo |= all_tag_names(rollup)
        memo
      end
    end

    TAG_MANAGED_PREFIX = "/tag/managed/".freeze

    def tag_prefix
      klass_prefix = case resource_type
                     when Container.name        then 'container_image'
                     when VmOrTemplate.name     then 'vm'
                     when ContainerProject.name then 'container_project'
                     end

      klass_prefix + TAG_MANAGED_PREFIX
    end

    def chargeback_container_labels
      resource.try(:container_image).try(:docker_labels).try(:collect_concat) do |l|
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
      if resource.kind_of?(Container)
        state = resource.vim_performance_state_for_ts(timestamp.to_s)
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
      @tag_list_with_prefix ||= @rollup_array.map { |rollup| tag_list_with_prefix_for(rollup) }.flatten.uniq
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
      grouped_rollups = @rollup_array.group_by { |x| x[ChargeableField.col_index(:resource_id)] }

      @grouped_values[metric] ||= grouped_rollups.map do |_, rollups|
        rollups.map { |x| x[ChargeableField.col_index(metric)] }.compact.max
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
      @chargeback_fields_present ||= @rollup_array.count { |rollup| chargeback_fields_present?(rollup) }
    end

    def chargeback_fields_present?(rollup_record)
      MetricRollup::CHARGEBACK_METRIC_FIELDS.any? do |field|
        rollup = rollup_record[ChargeableField.col_index(field)]
        rollup.present? && rollup.nonzero?
      end
    end

    def metering_used_fields_present?(rollup_record)
      MetricRollup::METERING_USED_METRIC_FIELDS.any? do |field|
        rollup = rollup_record[ChargeableField.col_index(field)]
        rollup.present? && rollup.nonzero?
      end
    end

    def metering_used_fields_present
      @metering_used_fields_present ||= @rollup_array.count { |rollup| metering_used_fields_present?(rollup) }
    end

    def metering_allocated_for(metric)
      @metering_allocated_metric ||= {}
      @metering_allocated_metric[metric] ||= @rollup_array.count do |rollup|
        rollup_record = rollup[ChargeableField.col_index(metric)]
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

    private

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
        sub_metric ? sub_metric_rollups(sub_metric) : @rollup_array.collect { |x| x[ChargeableField.col_index(metric)] }.compact
      end
    end

    def first_metric_rollup_record
      first_rollup_id = @rollup_array.first[ChargeableField.col_index(:id)]
      @fmrr ||= MetricRollup.find(first_rollup_id) if first_rollup_id
    end
  end
end
