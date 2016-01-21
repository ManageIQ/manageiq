class ExtManagementSystemDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end
end
