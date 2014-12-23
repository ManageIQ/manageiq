module OpsHelper
  include_concern 'TextualSummary'

  def hide_button(button, opt)
    if opt == "on"
      button ? '' : 'display:none'
    else
      button ? 'display:none' : ''
    end
  end
end
