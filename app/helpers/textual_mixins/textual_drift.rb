module TextualMixins::TextualDrift
  def textual_drift
    return nil unless role_allows?(:feature => "vm_drift")
    h = {:label => _("Drift History"), :icon => "product product-drift"}
    num = @record.number_of(:drift_states)
    if num == 0
      h[:value] = _("None")
    else
      h[:value] = num
      h[:title] = _("Show virtual machine drift history")
      h[:explorer] = true
      h[:link] = url_for(:controller => controller.controller_name, :action => 'drift_history', :id => @record)
    end
    h
  end
end
