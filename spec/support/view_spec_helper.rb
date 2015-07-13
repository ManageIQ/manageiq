require 'haml-rails'

module ViewSpecHelper
  def show_element(resp, id)
    set_element_visibility(resp, id, true)
  end

  def hide_element(resp, id)
    set_element_visibility(resp, id, false)
  end

  private

  def set_element_visibility(resp, id, visible)
    c = Capybara.string(resp)
    node = c.find(id, :visible => :all)
    node.native["style"] = node.native["style"].gsub(/display\s*:[^;]+/, "display:#{visible ? "show" : "none"}")
    c.native.to_s
  end

  def set_controller_for_view(controller_name)
    controller.request.path_parameters[:controller] = controller_name
  end
end
