class MiqCimInstanceDecorator < Draper::Decorator
  delegate_all

  def quadicon
    Quadicons::MiqCimInstanceQuadicon
  end
end
