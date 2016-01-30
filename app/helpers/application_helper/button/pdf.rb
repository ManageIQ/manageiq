class ApplicationHelper::Button::Pdf < ApplicationHelper::Button::Basic
  def skip?
    !PdfGenerator.available?
  end
end
