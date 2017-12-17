class BottleneckEvent < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  serialize :context_data

  def self.last_created_on(obj)
    event = where(:resource => obj).order("created_on DESC").first
    event.try(:created_on)
  end

  def self.generate_future_events(obj)
    log_message_uniq_prefix = "Generating future bottleneck events for: [#{obj.class} - #{obj.name}]..."
    last = last_created_on(obj)
    if last && last >= 24.hours.ago.utc
      _log.info("#{log_message_uniq_prefix} Skipped, last creation [#{last}] was less than 24 hours ago")
      return
    end
    dels = delete_future_events_for_obj(obj)
    adds = 0
    future_event_definitions_for_obj(obj).each do |e|
      result = calculate_future_event(obj, e[:definition][:calculation])
      next if result.blank? || result[:timestamp].nil?
      # TODO: determine wheter we omit results that are in the past

      event = new(e[:definition][:event])
      event.future        = true
      event.resource      = obj
      event.resource_name = obj.name if obj.respond_to?(:name)
      event.timestamp     = result.delete(:timestamp)
      event.context_data  = e[:definition].merge(result)
      event.message       = event.substitute(event.message)
      if event.save
        adds += 1
      else
        _log.warn("#{log_message_uniq_prefix} failed with '#{event.errors.full_messages.join(', ')}'")
      end
    end

    _log.info("#{log_message_uniq_prefix} Complete - Added #{adds} / Deleted #{dels}")
  end

  def self.calculate_future_event(obj, options)
    method = "calculate_future_#{options[:name]}"
    raise _("'%{name}', calculation not supported") % {:name => options[:name]} unless respond_to?(method)
    send(method, obj, options)
  end

  def self.event_definitions(event_type)
    @event_definitions ||= {}
    @event_definitions[event_type] ||= MiqEventDefinition.where(:event_type => event_type).to_a
  end

  def self.future_event_definitions_for_obj(obj)
    search_type = obj.class.base_class.name.to_sym
    event_definitions("projected").find_all { |e| e[:definition][:applies_to].include?(search_type) }
  end

  def self.delete_future_events_for_obj(obj)
    where(:resource => obj, :future => true).delete_all
  end

  def context
    context_data
  end

  def dictionary(col)
    Dictionary.gettext(col.to_s, :type => "column")
  end

  def format(value, method, options = {})
    MiqReport.new.send(method, value, options)
  end

  def substitute(str)
    eval("result = \"#{str}\"")
  end

  # Future event calculation methods
  def self.calculate_future_trend_to_limit(obj, options)
    # => Returns: {
    # =>  :timestamp => timstamp when trend line meets limit,
    # =>  :trend_attr_value => value of trend attr at timestamp,
    # =>  :limit_attr_value => value of limit attr
    # => }

    # TODO: remove `to_a` when `calc_timestamp_at_trend` / `slope` no longer sorts or iterates multiple times
    recs = VimPerformanceAnalysis.find_perf_for_time_period(obj, options[:interval], options).to_a

    limit_value = recs.last.try(options[:limit_attr])
    return if limit_value.nil?

    limit_value = (limit_value * options[:limit_pct] / 100.0) if options[:limit_pct]

    result = {:limit_attr_value => limit_value}

    ts = VimPerformanceAnalysis.calc_timestamp_at_trend_value(recs, options[:trend_attr], result[:limit_attr_value])
    if ts && (ts <= 1.year.from_now.utc && ts >= 6.months.ago.utc)
      result[:timestamp] = ts
    else
      return
    end
    result
  end

  def self.event_where_clause(obj)
    ids_hash = child_types_and_ids(obj)
    result = ["(resource_type = '#{obj.class.base_class.name}' AND resource_id = #{obj.id})"]
    ids_hash.each { |k, v| result.push("(resource_type = '#{k}' AND resource_id in (#{v.join(",")}))") }
    result.join(" OR ")
  end

  def self.child_types_and_ids(obj)
    result = {}
    relats = case obj.class.base_class.name
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

      result[recs.first.class.base_class.name] = recs.collect(&:id)
      recs.each do |child|
        child_types_and_ids(child).each do |k, v|
          result[k] ||= []
          result[k].concat(v)
        end
      end
    end
    result
  end

  def self.remove_duplicate_find_results(recs)
    seen = []
    recs.inject([]) do |a, r|
      key = [r.resource_type, r.resource_id, r.event_type, r.severity, r.message].join("|")
      next(a) if seen.include?(key)
      seen << key
      a << r
    end
  end
end
