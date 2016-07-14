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
      self[:title] = case @view_context.x_node.split("_").last.split('-')[0]
                     when 'a'  then N_("This Action belongs to a read only Policy and cannot be modified")
                     when 'ev' then N_("This Event belongs to a read only Policy and cannot be modified")
                     end
    end
  end
end
