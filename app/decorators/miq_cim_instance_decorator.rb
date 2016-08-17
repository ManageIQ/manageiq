class MiqCimInstanceDecorator < Draper::Decorator
  delegate_all

  def quadicon
    Quadicons::Base
  end

  def quadicon_image_path
    "100/miq_cim_instance.png"
  end

  def quadicon_title
    evm_display_name
  end
end
