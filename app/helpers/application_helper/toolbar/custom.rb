ApplicationHelper::Toolbar::Custom = Struct.new(:name, :args) do
  def render(_view_context)
    # FIXME: assigns? locals? view_binding? instance_data?
    @content = ApplicationController.renderer.render :partial => args[:partial]
  end

  attr_reader :content
end
