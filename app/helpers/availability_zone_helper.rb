module AvailabilityZoneHelper
  include_concern 'TextualSummary'

  def accessible_select_event_types
    [[_('Management Events'), 'timeline']]
  end
end
