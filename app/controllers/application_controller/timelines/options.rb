module ApplicationController::Timelines
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
    :tl_show_options,
    :typ
  ) do
    def all_results
      {_('Both') => 'both', _('True') => 'success', _('False') => 'failure'}
    end

    def evt_type
      tl_show == 'timeline' ? :event_streams : :policy_events
    end

    def tl_colors
      ['#CD051C', '#005C25', '#035CB1', '#FF3106', '#FF00FF', '#000000']
    end

    def events
      MiqEventDefinitionSet.all.each_with_object({}) do |event, hash|
        hash[event.description] = event.members.collect(&:id)
      end
    end
  end
end
