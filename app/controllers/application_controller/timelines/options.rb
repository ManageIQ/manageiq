module ApplicationController::Timelines
  SELECT_EVENT_TYPE = [[_('Management Events'), 'timeline'], [_('Policy Events'), 'policy_timeline']].freeze
  SELECT_RESULT_TYPE = {_('Both') => 'both', _('True') => 'success', _('False') => 'failure'}.freeze
  EVENT_COLORS = ['#CD051C', '#005C25', '#035CB1', '#FF3106', '#FF00FF', '#000000'].freeze

  DateOptions = Struct.new(
    :daily,
    :days,
    :end,
    :hourly,
    :start,
    :typ
  ) do
    def update_from_params(params)
      self.typ = params[:tl_typ] if params[:tl_typ]
      self.days = params[:tl_days] if params[:tl_days]
      self.hourly = params[:miq_date_1] if params[:miq_date_1] && typ == 'Hourly'
      self.daily = params[:miq_date_1] if params[:miq_date_1] && typ == 'Daily'
    end

    def update_start_end(sdate, edate)
      if !sdate.nil? && !edate.nil?
        self.start = [sdate.year.to_s, (sdate.month - 1).to_s, sdate.day.to_s].join(", ")
        self.end = [edate.year.to_s, (edate.month - 1).to_s, edate.day.to_s].join(", ")
        self.hourly ||= [edate.month, edate.day, edate.year].join("/")
        self.daily ||= [edate.month, edate.day, edate.year].join("/")
      else
        self.start = self.end = nil
      end
      self.days ||= "7"
    end
  end

  ManagementEventsOptions = Struct.new(
    :level,
    :filter1,
    :filter2,
    :filter3
  ) do
    def fltr1
      filter1.blank? ? '' : build_filter(events[filter1])
    end

    def fltr2
      filter2.blank? ? '' : build_filter(events[filter2])
    end

    def fltr3
      filter3.blank? ? '' : build_filter(events[filter3])
    end

    def events
      @events ||= EmsEvent.event_groups.each_with_object({}) do |egroup, hash|
        gname, list = egroup
        hash[list[:name].to_s] = gname
      end
    end

    def drop_cache
      @events = nil
    end

    private

    def build_filter(grp_name) # hidden fields to highlight bands in timeline
      event_groups = EmsEvent.event_groups
      arr = event_groups[grp_name][level.downcase.to_sym]
      arr.push(event_groups[grp_name][:critical]) if level.downcase == 'detail'
      "(" << arr.join(")|(") << ")"
    end
  end

  Options = Struct.new(
    :applied_filters,
    :date,
    :model,
    :mngt,
    :pol_filter,
    :pol_fltr,
    :tl_filter_all,
    :tl_result,
    :tl_show,
  ) do
    def initialize(*args)
      super
      self.date = DateOptions.new
      self.mngt = ManagementEventsOptions.new
    end

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
      mngt.drop_cache
    end
  end
end
