class MiddlewareDatasourceDecorator < Draper::Decorator
  delegate_all
  include MiddlewareDecoratorMixin

  def fonticon
    'fa fa-database'.freeze
  end

  # Determine the icon
  def item_image
    'middleware_datasource'
  end
end
