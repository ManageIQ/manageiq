class ApplicationHelper::Button::Separator < ApplicationHelper::Button::ButtonWithoutRbackCheck
  def initialize(props)
    super(nil, nil, {}, props)
    self[:type] = :separator
  end
end
