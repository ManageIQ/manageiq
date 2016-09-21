class ApplicationHelper::Button::Separator < ApplicationHelper::Button::ButtonWithoutRbacCheck
  def initialize(props)
    super(nil, nil, {}, props)
    self[:type] = :separator
  end
end
