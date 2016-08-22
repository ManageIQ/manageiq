ApplicationHelper::Toolbar::Custom = Struct.new(:name, :args) do
  def render(view_context)
    # FIXME: assigns? locals? view_binding? instance_data?
    @content = view_context.render :partial => args[:partial]
  end

  attr_reader :content
end
