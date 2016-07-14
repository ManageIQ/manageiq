class MiddlewareServerPerformance < ActsAsArModel
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
    start_time, end_time, interval = parse_time_interval(options)
    results = []
    MiddlewareServer.find_each do |ms|
      raw_stats = fetch_raw_stats(ms, start_time, end_time, interval)
      if raw_stats.values[0]
        columns = raw_stats.values[0].keys
        columns.each { |column| set_columns_hash(column => :float) }
        raw_stats.each { |timestamp, stats| results.push(parse_row(ms, timestamp, interval, stats)) }
      end
    end
    [results, {}]
  end

  def self.parse_time_interval(options)
    now = Time.now.utc
    start_time = now - options[:start_offset]
    end_time = now - options[:end_offset]
    interval = case options[:interval]
               when 'daily'   then 1.day.seconds
               when 'hourly'  then 1.hour.seconds
               else end_time - start_time
               end
    [start_time, end_time, interval]
  end

  def self.fetch_raw_stats(middleware_server, start_time, end_time, interval)
    raw_stats = {}
    middleware_server.metrics_available.each do |metric|
      middleware_server.collect_stats_metric(metric, start_time, end_time, interval).each do |stat|
        timestamp = stat['start']
        raw_stats[timestamp] = {} if raw_stats[timestamp].nil?
        %w(min avg median max samples).each do |w|
          raw_stats[timestamp]["#{metric[:name]}_#{w}"] = stat[w]
        end
      end unless metric[:type] == "AVAILABILITY"
    end
    raw_stats
  end

  def self.parse_row(middleware_server, timestamp, interval, stats)
    start_time = Time.at(timestamp / 1000).utc
    row = MiddlewareServerPerformance.new
    %w(id name feed ems_ref).each { |field| row[field] = middleware_server[field] }
    row[:resource_type] = middleware_server.class.name
    row[:start_time] = start_time
    row[:end_time] = start_time + interval
    stats.each { |metric_name, value| row[metric_name] = value }
    row
  end

  def to_a
    [self]
  end
end
