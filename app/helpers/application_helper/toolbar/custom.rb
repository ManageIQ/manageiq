ApplicationHelper::Toolbar::Custom = Struct.new(:name, :args) do
  def render(view_context)
    @content = view_context.render_to_string(:template => args[:partial])
  end

  attr_reader :content
end
