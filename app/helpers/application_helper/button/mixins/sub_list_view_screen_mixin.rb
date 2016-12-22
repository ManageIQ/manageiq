module ApplicationHelper::Button::Mixins::SubListViewScreenMixin
  def sub_list_view_screen?
    @lastaction == 'show' && !@display.in?(%w(main vms instances))
  end
end
