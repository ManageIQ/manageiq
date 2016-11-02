class ApplicationHelper::Button::ConfiguredSystemProvision < ApplicationHelper::Button::Basic
  def visible?
    # return true if @record not present or method not implemented
    @record.provisionable? rescue true
  end
end
