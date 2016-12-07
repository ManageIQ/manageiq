class ApplicationHelper::Button::EmsNetwork < ApplicationHelper::Button::Basic
  def visible?
    ::Settings.product.nuage
  end
end
