class MiddlewarePerformance < ActsAsArModel
  set_columns_hash(
    :id            => :string,
    :name          => :string,
    :resource_type => :string,
    :feed          => :string,
    :ems_ref       => :string,
    :start_time    => :datetime,
    :end_time      => :datetime
  )

  alias resource_id id
  alias resource_name name

  def self.build_results_for_report_middleware(options)
    check_if_current_class_implements_model_class

    report_cols = options[:report_cols]
    start_time, end_time, interval = parse_time_interval(options)
    results = []

    model_class.find_each do |ms|
      begin
        raw_stats = ms.collect_report_metrics(report_cols, start_time, end_time, interval)
      rescue ::Hawkular::BaseClient::HawkularConnectionException => exception
        $log.error(exception)
        next
      end
      if raw_stats.values[0]
        parse_raw_stats_columns(raw_stats)
        raw_stats.each { |timestamp, stats| results.push(parse_row(ms, timestamp, interval, stats)) }
      end
    end
    [results, {}]
  end

  def self.check_if_current_class_implements_model_class
    raise 'You are not supposed to use MiddlewarePerformance model for reporting.' if self == MiddlewarePerformance
    raise 'You need to implement :model_class in your model. ' unless respond_to?(:model_class)
  end

  def self.parse_raw_stats_columns(raw_stats)
    columns = raw_stats.values[0].keys
    columns.each { |column| set_columns_hash(column => :float) }
  end

  def self.parse_time_interval(options)
    now = Time.now.utc
    start_time = now - options[:start_offset]
    end_time = now - options[:end_offset]
    interval = case options[:interval]
               when 'daily'   then 1.day.seconds
               when 'hourly'  then 1.hour.seconds
               when 'every minute' then 1.minute.seconds
               else end_time - start_time
               end
    [start_time, end_time, interval]
  end

  def self.parse_row(middleware_model, timestamp, interval, stats)
    start_time = Time.at(timestamp).utc
    row = new
    %w(id name feed ems_ref).each { |field| row[field] = middleware_model[field] }
    row[:resource_type] = middleware_model.class.name
    row[:start_time] = start_time
    row[:end_time] = start_time + interval
    stats.each { |metric_name, value| row[metric_name] = value }
    row
  end

  def to_a
    [self]
  end
end
