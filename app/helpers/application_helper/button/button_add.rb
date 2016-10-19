class ApplicationHelper::Button::ButtonAdd < ApplicationHelper::Button::ButtonWithoutRbacCheck
  needs :@edit

  def visible?
    !@edit[:rec_id]
  end

  def disabled?
    !@changed
  end
end
