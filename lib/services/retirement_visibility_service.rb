class RetirementVisibilityService
  def determine_visibility(retirement)
    fields_to_edit = []
    fields_to_hide = []

    if retirement.positive?
      fields_to_edit += [:retirement_warn]
    else
      fields_to_hide += [:retirement_warn]
    end

    {:hide => fields_to_hide, :edit => fields_to_edit}
  end
end
