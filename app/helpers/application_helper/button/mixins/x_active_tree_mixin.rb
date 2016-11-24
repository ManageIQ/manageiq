module ApplicationHelper::Button::Mixins::XActiveTreeMixin
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
