class ApplicationHelper::Button::PolicyCopyButton < ApplicationHelper::Button::Basic
  needs_record

  def initialize(view_context, view_binding, instance_data, props)
    super(view_context, view_binding, instance_data, props)
    @feature = props[:options][:feature]
    @condition = props[:options][:condition]
  end

  def skip?
    !role_allows?(:feature => @feature) || self.instance_eval(&@condition)
  end

  private
  delegate :x_active_tree, :role_allows?, :to => :@view_context
end
