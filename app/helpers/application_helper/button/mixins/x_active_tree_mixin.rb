module ApplicationHelper::Button::Mixins::XActiveTreeMixin
  # This method basically does the following things:
  #   - Checks whether the not implemented method's name
  #     has a "_tree?" suffix or not.
  #   - In case it does have the suffix, it then looks up
  #     the active tree in the @view_context and checks it
  #     against the method's name without ''?'. E.g.:
  #     in case of method call ':reports_tree?' it will check
  #     whether @view_context.x_active_tree == :reports_tree.
  #   - Otherwise it raises an error.
  def method_missing(name, *_args, &_block)
    return active_tree?(name.to_s) if tree_method?(name.to_s)
    raise NoMethodError
  end

  def tree_method?(name)
    name =~ /^.+_tree\?$/
  end

  def tree_method(name)
    name.scan(/^(.+_tree)\?$/).first.first
  end

  def active_tree?(name)
    @view_context.x_active_tree == tree_method(name).to_sym
  end
end
