class ApplicationHelper::Button::MiqActionModify < ApplicationHelper::Button::Basic
  def disabled?
    @view_context.x_node.split("_").any? do |level|
      node_type, id = level.split('-')
      node_type == 'p' && MiqPolicy.find_by(:id => id).try(:read_only)
    end
  end

  def calculate_properties
    super
    node_type = @view_context.x_node.split("_").last.split('-')[0].to_sym

    ent = {
      :a  => ui_lookup(:model => "MiqAction"),
      :ev => ui_lookup(:table => "event")
    }[node_type]

    params = {:entity => ent, :policy => ui_lookup(:model => "MiqPolicy")}
    self[:title] = N_("This %{entity} belongs to a read only %{policy} and cannot be modified" % params) if disabled?
  end
end
