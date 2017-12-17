# EventMixin expects that event_where_clause is defined in the model.
module EventMixin
  extend ActiveSupport::Concern

  included do
    supports :timeline
  end

  def first_event(assoc = :ems_events)
    event = find_one_event(assoc, "timestamp ASC")
    event.try(:timestamp)
  end

  def last_event(assoc = :ems_events)
    event = find_one_event(assoc, "timestamp DESC")
    event.try(:timestamp)
  end

  def first_and_last_event(assoc = :ems_events)
    [first_event(assoc), last_event(assoc)].compact
  end

  def has_events?(assoc = :ems_events)
    # TODO: homemade caching is probably harfmul as it's not expected.
    # It should be considered for removal.
    @has_events ||= {}
    return @has_events[assoc] if @has_events.key?(assoc)
    @has_events[assoc] = events_assoc_class(assoc).where(event_where_clause(assoc)).exists?
  end

  def events_assoc_class(assoc)
    assoc.to_s.classify.constantize
  end

  def events_table_name(assoc)
    events_assoc_class(assoc).table_name
  end

  private

  def find_one_event(assoc, order)
    ewc = event_where_clause(assoc)
    events_assoc_class(assoc).where(ewc).order(order).first unless ewc.blank?
  end
end
