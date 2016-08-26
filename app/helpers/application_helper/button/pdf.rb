class ApplicationHelper::Button::Pdf < ApplicationHelper::Button::Basic
  def visible?
    PdfGenerator.available?
  end
end
