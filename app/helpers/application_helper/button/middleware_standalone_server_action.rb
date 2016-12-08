class ApplicationHelper::Button::MiddlewareStandaloneServerAction < ApplicationHelper::Button::MiddlewareServerAction

  def visible?
    !in_domain? && super
  end

  private

  def in_domain?
    @record.present? && (@record.try(:in_domain?) || @record.try(:middleware_server).try(:in_domain?))
  end
end
