class ApplicationHelper::Button::DeleteServer < ApplicationHelper::Button::ZoneDeleteServer
  needs :@record

  def calculate_properties
    super
    self[:title] = @error_message if disabled?
  end

  def disabled?
    @error_message = unless @record.is_deleteable?
                       N_("Server %{server_name} [%{server_id}] can only be deleted if it is stopped or has not responded for a while") %
                         {:server_name => @record.name, :server_id => @record.id}
                     end
    @error_message.present?
  end

end
