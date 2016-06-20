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

    def mngmt_events
      @mngmt_events ||= EmsEvent.event_groups.each_with_object({}) do |egroup, hash|
        gname, list = egroup
        hash[list[:name].to_s] = gname
      end
    end

    def fltr1
      filter1.blank? ? '' : mngmt_build_filter(mngmt_events[filter1])
    end

    def fltr2
      filter2.blank? ? '' : mngmt_build_filter(mngmt_events[filter2])
    end

    def fltr3
      filter3.blank? ? '' : mngmt_build_filter(mngmt_events[filter3])
    end

    def drop_cache
      @policy_events = @mngmt_events = nil
    end

    private

    def mngmt_build_filter(grp_name) # hidden fields to highlight bands in timeline
      event_groups = EmsEvent.event_groups
      arr = event_groups[grp_name][fl_typ.downcase.to_sym]
      arr.push(event_groups[grp_name][:critical]) if fl_typ.downcase == 'detail'
      "(" << arr.join(")|(") << ")"
    end
  end
end
