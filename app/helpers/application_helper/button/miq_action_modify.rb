class ApplicationHelper::Button::MiqActionModify < ApplicationHelper::Button::Basic
  def disabled?
    @view_context.x_node.split("_").any? do |level|
      node_type, id = level.split('-')
      node_type == 'p' && MiqPolicy.find_by(:id => id).try(:read_only)
    end
  end

  def calculate_properties
    super

    if disabled?
      self[:title] = N_("This %{entity} belongs to a read only %{policy} and cannot be modified") % {
        :entity => case @view_context.x_node.split("_").last.split('-')[0]
                   when 'a'  then ui_lookup(:model => "MiqAction")
                   when 'ev' then ui_lookup(:table => "event")
                   end,
        :policy => ui_lookup(:model => "MiqPolicy")
      }
    end
  end
end
