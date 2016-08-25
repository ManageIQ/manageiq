class ApplicationHelper::Button::PolicyButton < ApplicationHelper::Button::ReadOnly

  def initialize(view_context, view_binding, instance_data, props)
    super(view_context, view_binding, instance_data, props)
    @feature = props[:options][:feature]
    @condition = props[:options][:condition]
  end

  def skip?
    @condition ? !role_allows?(:feature => @feature) || instance_eval(&@condition) : !role_allows?(:feature => @feature)
  end

  delegate :x_active_tree, :role_allows?, :to => :@view_context
end
