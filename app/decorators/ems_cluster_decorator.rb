class EmsClusterDecorator < Draper::Decorator
  delegate_all

  def quadicon
    Quadicons::EmsClusterQuadicon
  end

  def quadicon_image_path
    "100/emscluster.png"
  end
end
