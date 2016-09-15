class ApplicationHelper::Button::PolicyButton < ApplicationHelper::Button::ReadOnly

  def initialize(view_context, view_binding, instance_data, props)
    super
    @feature = props[:options][:feature]
  end

  delegate :x_active_tree, :to => :@view_context
end
