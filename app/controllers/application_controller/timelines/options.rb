module ApplicationController::Timelines
  SELECT_EVENT_TYPE = [[_('Management Events'), 'timeline'], [_('Policy Events'), 'policy_timeline']].freeze
  SELECT_RESULT_TYPE = {_('Both') => 'both', _('True') => 'success', _('False') => 'failure'}.freeze
  EVENT_COLORS = ['#CD051C', '#005C25', '#035CB1', '#FF3106', '#FF00FF', '#000000'].freeze

  Options = Struct.new(
    :applied_filters,
    :daily_date,
    :days,
    :edate,
    :filter1,
    :filter2,
    :filter3,
    :fltr1,
    :fltr2,
    :fltr3,
    :fl_typ,
    :hourly_date,
    :model,
    :pol_filter,
    :pol_fltr,
    :sdate,
    :tl_filter_all,
    :tl_result,
    :tl_show,
    :typ
  ) do
    def management_events?
      tl_show == 'timeline'
    end

    def policy_events?
      tl_show == 'policy_timeline'
    end

    def evt_type
      management_events? ? :event_streams : :policy_events
    end

    def policy_event_filter_any?
      pol_filter.any? { |f| !f.blank? }
    end

    def policy_events
      @policy_events ||= MiqEventDefinitionSet.all.each_with_object({}) do |event, hash|
        hash[event.description] = event.members.collect(&:id)
      end
    end

    def drop_cache
      @policy_events = nil
    end
  end
end
