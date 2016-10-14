class ApplicationHelper::Button::TenantEdit < ApplicationHelper::Button::Basic
  needs :@record

  def disabled?
    @record.source
  end
end
