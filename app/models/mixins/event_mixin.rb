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

  def event_stream_filters
    {
      "EmsEvent".freeze => ems_event_filter,
      "MiqEvent".freeze => miq_event_filter
    }
  end

  private

  def ems_event_filter
    {self.class.ems_event_filter_column => id}
  end

  def miq_event_filter
    filter = {self.class.miq_event_filter_column => id}
    filter["target_type"] = self.class.base_class.name if filter.key?("target_id")
    filter
  end

  def find_one_event(assoc, order)
    ewc = event_where_clause(assoc)
    events_assoc_class(assoc).where(ewc).order(order).first if ewc.present?
  end

  module ClassMethods
    def ems_event_filter_column
      @ems_event_filter_column ||= reflect_on_association(:ems_events).try(:foreign_key) || name.foreign_key
    end

    def miq_event_filter_column
      @miq_event_filter_column ||= reflect_on_association(:miq_events).try(:foreign_key) || "target_id".freeze
    end
  end
end
