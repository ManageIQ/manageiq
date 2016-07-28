class RetirementVisibilityService
  def determine_visibility(retirement)
    fields_to_show = []
    fields_to_hide = []

    if retirement > 0
      fields_to_show += [:retirement_warn]
    else
      fields_to_hide += [:retirement_warn]
    end

    {:hide => fields_to_hide, :show => fields_to_show}
  end
end
