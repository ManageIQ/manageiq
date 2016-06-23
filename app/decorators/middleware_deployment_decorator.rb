class MiddlewareDeploymentDecorator < Draper::Decorator
  delegate_all
  include MiddlewareDecoratorMixin

  def fonticon
    if name.end_with? '.ear'
      'product-file-ear-o'
    elsif name.end_with? '.war'
      'product-file-war-o'
    else
      'product-report'
    end
  end

  # Determine the icon
  # we want to display a different icon depending of the type
  # of server we have.
  def item_image
    if name.end_with? '.ear'
      'middleware_deployment_ear'
    elsif name.end_with? '.war'
      'middleware_deployment_war'
    else
      'middleware_deployment'
    end
  end
end
