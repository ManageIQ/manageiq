class BottleneckEvent < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true

  include ReportableMixin

  serialize :context_data

  def self.last_created_on(obj)
    event = self.where("resource_type = ? AND resource_id = ?", obj.class.name, obj.id).order("created_on DESC").first
    return event ? event.created_on : nil
  end

  def self.generate_future_events(obj)
    $log.info("MIQ(BottleneckEvent-generate_future_events) Generating future bottleneck events for: [#{obj.class} - #{obj.name}]...")
    last = self.last_created_on(obj)
    if last && last >= 24.hours.ago.utc
      $log.info("MIQ(BottleneckEvent-generate_future_events) Generating future bottleneck events for: [#{obj.class} - #{obj.name}]... Skipped, last creation [#{last}] was less than 24 hours ago")
      return
    end
    dels = self.delete_future_events_for_obj(obj)
    adds = 0
    self.future_event_definitions_for_obj(obj).each do |e|
      result = self.calculate_future_event(obj, e[:definition][:calculation])
      next if result.blank? || result[:timestamp].nil?
      # TODO: determine wheter we omit results that are in the past

      event = self.new(e[:definition][:event])
      event.future        = true
      event.resource      = obj
      event.resource_name = obj.name if obj.respond_to?(:name)
      event.timestamp     = result.delete(:timestamp)
      event.context_data  = e[:definition].merge(result)
      event.message       = event.substitute(event.message)
      event.save
      adds += 1
    end

    $log.info("MIQ(BottleneckEvent-generate_future_events) Generating future bottleneck events for: [#{obj.class} - #{obj.name}]... Complete - Added #{adds} / Deleted #{dels}")
  end

  def self.calculate_future_event(obj, options)
    method = "calculate_future_#{options[:name]}"
    raise "'#{options[:name]}', calculation not supported" unless self.respond_to?(method)
    self.send(method, obj, options)
  end

  def self.event_definitions(event_type)
    @event_definitions             ||= {}
    @event_definitions[event_type] ||= MiqEvent.where(:event_type => event_type).to_a
  end

  def self.future_event_definitions_for_obj(obj)
    search_type = obj.class.base_class.name.to_sym
    event_definitions("projected").find_all { |e| e[:definition][:applies_to].include?(search_type) }
  end

  def self.delete_future_events_for_obj(obj)
    self.delete_all(:resource_type => obj.class.name, :resource_id => obj.id, :future => true)
  end

  def context
    return self.context_data
  end

  def dictionary(col)
    Dictionary.gettext(col.to_s, :type => "column")
  end

  def format(value, method, options={})
    MiqReport.new.send(method, value, options)
  end

  def substitute(str)
    eval "result = \"#{str}\""
  end

  # Future event calculation methods
  def self.calculate_future_trend_to_limit(obj, options)
    # => Returns: {
    # =>  :timestamp => timstamp when trend line meets limit,
    # =>  :trend_attr_value => value of trend attr at timestamp,
    # =>  :limit_attr_value => value of limit attr
    # => }

    recs = VimPerformanceAnalysis.find_perf_for_time_period(obj, options[:interval], options)
    return if recs.blank?

    limit_value = recs.last.send(options[:limit_attr])
    return if limit_value.nil?

    limit_value = (limit_value * options[:limit_pct] / 100.0) if options[:limit_pct]

    result = {:limit_attr_value => limit_value}

    ts = VimPerformanceAnalysis.calc_timestamp_at_trend_value(recs, options[:trend_attr], result[:limit_attr_value])
    if ts && (ts <= 1.year.from_now.utc && ts >= 6.months.ago.utc)
      result[:timestamp] = ts
    else
      return
    end
    return result
  end

  def self.event_where_clause(obj)
    ids_hash = self.child_types_and_ids(obj)
    result = ["(resource_type = '#{obj.class.name}' AND resource_id = #{obj.id})"]
    ids_hash.each { |k,v| result.push("(resource_type = '#{k}' AND resource_id in (#{v.join(",")}))") }
    return result.join(" OR ")
  end

  def self.child_types_and_ids(obj)
    result = {}
    relats = case obj.class.name
    when "MiqEnterprise"
      [:ext_management_systems, :storages]
    when "MiqRegion"
      [:ext_management_systems, :storages]
    when "ExtManagementSystem"
      [:ems_clusters, :hosts]
    when "EmsCluster"
      [:hosts]
    else
      return result
    end

    relats.each do |r|
      recs = obj.send(r)
      next if recs.blank?

      result[recs.first.class.name] = recs.collect(&:id)
      recs.each do |child|
        self.child_types_and_ids(child).each do |k,v|
          result[k] ||= []
          result[k].concat(v)
        end
      end
    end
    return result
  end

  def self.remove_duplicate_find_results(recs)
    seen = []
    recs.inject([]) do |a,r|
      key = [r.resource_type, r.resource_id, r.event_type, r.severity, r.message].join("|")
      next(a) if seen.include?(key)
      seen << key
      a << r
    end
  end
end
