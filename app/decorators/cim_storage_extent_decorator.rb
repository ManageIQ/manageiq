class CimStorageExtentDecorator < Draper::Decorator
  delegate_all

  def quadicon
    Quadicons::Base
  end

  def quadicon_image_path
    "100/cim_base_storage_extent.png"
  end

  def quadicon_title
    evm_display_name
  end
end
