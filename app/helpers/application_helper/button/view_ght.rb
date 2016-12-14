class ApplicationHelper::Button::ViewGHT < ApplicationHelper::Button::Basic
  include ApplicationHelper::Button::Mixins::XActiveTreeMixin

  def visible?
    reports_tree? || savedreports_tree? ? proper_type? : true
  end

  private

  def proper_type?
    @ght_type != "tabular" || @report.try(:graph).present? || @zgraph
  end
end
