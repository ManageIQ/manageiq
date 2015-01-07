# EventMixin expects that event_where_clause is defined in the model.
module EventMixin
  def first_event(assoc=:ems_events)
    event = find_one_event(assoc, "timestamp ASC")
    return event.nil? ? nil : event.timestamp
  end

  def last_event(assoc=:ems_events)
    event = find_one_event(assoc, "timestamp DESC")
    return event.nil? ? nil : event.timestamp
  end

  def first_and_last_event(assoc=:ems_events)
    return [first_event(assoc), last_event(assoc)].compact
  end

  def has_events?(assoc=:ems_events)
    @has_events ||= {}
    return @has_events[assoc] if @has_events.has_key?(assoc)

    klass = assoc.to_s.singularize.camelize.constantize
    @has_events[assoc] = klass.where(event_where_clause(assoc)).exists?
  end

  private

  def find_one_event(assoc, order)
    ewc = self.event_where_clause(assoc)
    return nil if ewc.blank?

    klass = if assoc == :ems_events
      EmsEvent
    elsif assoc == :policy_events
      PolicyEvent
    end
    return nil if klass.blank?

    event = klass.where(ewc).order(order).first
  end

end
