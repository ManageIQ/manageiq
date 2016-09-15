class ApplicationHelper::Button::PolicyCopy < ApplicationHelper::Button::PolicyButton
  def visible?
    x_active_tree == :policy_tree
  end
end
