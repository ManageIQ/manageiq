# EventMixin expects that event_where_clause_ems_events is defined as most
# classes have specific columns added to event_streams for their type.
# Alternatively, a model can override event_where_clause for custom logic.
#
# event_where_clause_miq_events defaults to automatically lookup policy events via the
# belongs_to target (target_type, target_id) association.
# If this isn't how policy events are created for a class, that class would need to be override
# this method with custom logic.
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

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events, :event_streams
      event_where_clause_ems_events
    when :miq_events, :policy_events
      event_where_clause_miq_events
    end
  end

  def event_where_clause_ems_events
    EmsEvent.where(belongs_to_column_id => id)
  end

  def event_where_clause_miq_events
    MiqEvent.where(belongs_to_column_id => id)
  end

  private

  def find_one_event(assoc, order)
    ewc = event_where_clause(assoc)
    events_assoc_class(assoc).where(ewc).order(order).first unless ewc.blank?
  end

  def belongs_to_column_id
    singular_base_class_name = self.class.base_class.name.tableize.singularize
    reflection = EventStream.reflections.detect do |name, ref|
      name.to_s == singular_base_class_name &&
        ref.kind_of?(ActiveRecord::Reflection::BelongsToReflection)
    end

    if reflection
      # Use reflection foreign_key if provided, otherwise reflection name + _id
      reflection.last.options.fetch(:foreign_key, "#{reflection.last.name}_id")
    else
      warn "belongs_to reflection missing in EventStream for #{self.class.base_class.name}, using #{singular_base_class_name}"
      "#{singular_base_class_name}_id"
    end
  end
end
