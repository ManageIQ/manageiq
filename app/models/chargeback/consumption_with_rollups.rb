class Chargeback
  class ConsumptionWithRollups < Consumption
    delegate :timestamp, :resource, :resource_id, :resource_name, :resource_type, :parent_ems,
             :parents_determining_rate,
             :to => :first_metric_rollup_record

    def initialize(metric_rollup_records, start_time, end_time)
      super(start_time, end_time)
      @rollups = metric_rollup_records
    end

    def tag_names
      @tag_names ||= @rollups.map { |m| m.tag_names.split('|') }.flatten.uniq
    end

    def max(metric)
      values(metric).max
    end

    def avg(metric)
      metric_sum = values(metric).sum
      metric_sum / consumed_hours_in_interval
    end

    def none?(metric)
      values(metric).empty?
    end

    def chargeback_fields_present
      @chargeback_fields_present ||= @rollups.count(&:chargeback_fields_present?)
    end

    def tag_list_with_prefix
      @tag_list_with_prefix ||= @rollups.map { |m| m.tag_list_with_prefix }.flatten.uniq
    end

    # def hash_features_affecting_rate
    #   @rollups.map { |m| m.hash_features_affecting_rate.split("|") }.flatten.uniq.join("|")
    # end

    def hash_features_affecting_rate
      @hash_features_affecting_rate ||= begin
        tags = tag_names.reject { |n| n.starts_with?('folder_path_') }.sort.join('|')
        keys = [tags] + first_metric_rollup_record.resource_parents.map(&:id)
        keys += [first_metric_rollup_record.resource.container_image, timestamp] if resource_type == Container.name
        keys.join('_')
      end
    end

    private

    def born_at
      # metrics can be older than resource (first capture may go few days back)
      [super, first_metric_rollup_record.timestamp].compact.min
    end

    def values(metric)
      @values ||= {}
      @values[metric] ||= @rollups.collect(&metric.to_sym).compact
    end

    def first_metric_rollup_record
      @fmrr ||= @rollups.first
    end
  end
end
