class LiveMetric < ActsAsArModel
  set_columns_hash(:timestamp => :datetime)

  class LiveMetricError < RuntimeError; end

  # all attributes are virtual
  # - attributes are dynamically generated and would be too much work to query/declare them all
  # - returning true gets the column names into the REST query (via :includes)
  def self.virtual_attribute?(_c)
    true
  end

  def self.find(*args)
    raw_query = args[1]
    validate_raw_query(raw_query)
    processed = process_conditions(raw_query[:conditions])
    resource = fetch_resource(processed[:resource_type], processed[:resource_id])
    filtered_cols = raw_query[:select] || raw_query[:include].keys.map(&:to_s)
    if resource.nil? || (processed[:interval_name] == 'daily' && processed[:start_time] > processed[:end_time])
      []
    else
      filter_and_fetch_metrics(resource, filtered_cols, processed[:start_time],
                               processed[:end_time], processed[:interval_name])
    end
  end

  def self.validate_raw_query(raw)
    unless raw && raw[:conditions]
      _log.error("LiveMetric expression #{raw} doesn't contain 'conditions'.")
      raise LiveMetricError, "LiveMetric expression doesn't contain 'conditions'"
    end
  end

  def self.parse_conditions(raw_conditions)
    if raw_conditions.index('or')
      _log.error("LiveMetric expression #{raw_conditions} must not contain 'or' operator.")
      raise LiveMetricError, "LiveMetric expression doesn't support 'or' operator"
    end
    raw_conditions.split('and').collect do |exp|
      parsed = exp.scan(/(.*)\s+(<=|=|>=|<|>|!=)\s+(.*)/)
      parse_condition(parsed[0][0], parsed[0][1], parsed[0][2])
    end
  end

  def self.parse_condition(column, op, value)
    value = value.strip
    value = value[1..value.length - 2] if value[0] == '\'' && value[value.length - 1] == '\''
    {:column => column.strip, :op => op.strip, :value => value}
  end

  def self.process_conditions(conditions)
    parsed_conditions = parse_conditions(conditions.first)
    processed = {}
    parsed_conditions.each do |condition|
      case condition[:column]
      when "resource_type"         then processed[:resource_type] = condition[:value]
      when "resource_id"           then processed[:resource_id] = condition[:value]
      when "timestamp"             then process_timestamps(processed, condition)
      when "capture_interval_name" then processed[:interval_name] = condition[:value]
      end
    end
    validate_conditions(processed)
    processed
  end

  def self.validate_conditions(processed)
    %i(resource_type resource_id start_time end_time interval_name).each do |k|
      unless processed.key?(k)
        _log.error("LiveMetric expression must contain #{k} condition.")
        raise LiveMetricError, "LiveMetric expression must contain #{k} condition"
      end
    end
  end

  def self.process_timestamps(processed, condition)
    ts = Time.parse("#{condition[:value]} UTC").utc
    if %w(>= > =).include?(condition[:op])
      processed[:start_time] = ts
    end
    if %w(<= < =).include?(condition[:op])
      processed[:end_time] = ts
    end
  end

  def self.fetch_resource(resource_type, resource_id)
    klass = Object.const_get(resource_type)
    if klass.exists?(resource_id)
      klass.find(resource_id)
    end
  end

  def self.filter_and_fetch_metrics(resource, filter, start_time, end_time, interval_name)
    filtered = resource.metrics_available.select { |metric| filter.nil? || filter.include?(metric[:name]) }
    filtered.each { |metric| set_columns_hash(metric[:name] => :float) }
    fetch_live_metrics(resource, filtered, start_time, end_time, interval_name)
  end

  def self.fetch_live_metrics(resource, metrics, start_time, end_time, interval_name)
    interval = case interval_name
               when "daily"  then 24 * 60 * 60
               when "hourly" then 60 * 60
               else 60
               end
    begin
      raw_metrics = resource.collect_live_metrics(metrics, start_time, end_time, interval)
      raw_metrics.collect do |ts, metric|
        processed_metric = LiveMetric.new
        processed_metric[:timestamp] = Time.at(ts).utc
        metric.each do |column, value|
          processed_metric[column] = value
        end
        processed_metric
      end
    rescue => err
      _log.error("An error occurred while connecting to #{resource}: #{err}")
    end
  end
end
