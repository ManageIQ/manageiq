class ApplicationHelper::Button::MiddlewareInstanceAdd < ApplicationHelper::Button::MiddlewareAction
  needs :@record

  def visible?
    !in_domain? && super
  end

  private

  def in_domain?
    @record.try(:in_domain?) || @record.try(:middleware_server).try(:in_domain?)
  end
end
