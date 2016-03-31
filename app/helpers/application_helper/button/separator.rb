class ApplicationHelper::Button::Separator < ApplicationHelper::Button::Basic
  def initialize(props)
    super(nil, nil, {}, props)
    self[:type] = 'separator'
  end
end
