module ManageIQ::Providers::Google::EventCatcherMixin
  def parse_event_type(event)
    event_type = event.fetch_path('structPayload', 'event_type')
    event_subtype = event.fetch_path('structPayload', 'event_subtype')

    event_type = "unknown" if event_type.blank?
    event_subtype = "unknown" if event_subtype.blank?

    event_type = event_type.downcase.camelize

    "#{event_type}_#{event_subtype}"
  end

  def parse_resource_id(event)
    resource_id = event.fetch_path('structPayload', 'resource', 'id')
    resource_id = "unknown" if resource_id.blank?

    resource_id
  end
end
