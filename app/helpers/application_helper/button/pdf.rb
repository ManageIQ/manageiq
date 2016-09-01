class ApplicationHelper::Button::Pdf < ApplicationHelper::Button::Basic
  def visible?
    PdfGenerator.available?
  end

  def check_rbac?
    true
  end
end
