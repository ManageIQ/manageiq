class MiddlewareDatasourceDecorator < Draper::Decorator
  delegate_all

  def fonticon
    'fa fa-database'.freeze
  end

  def listicon_image
    item_image
  end

  private

  # Determine the icon
  def item_image
    'middleware_datasource'
  end
end
