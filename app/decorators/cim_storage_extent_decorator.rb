class CimStorageExtentDecorator < Draper::Decorator
  delegate_all

  def quadicon
    Quadicons::CimStorageExtentQuadicon
  end
end
