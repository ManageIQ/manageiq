class ManageIQ::Providers::Amazon::CloudManager::AuthKeyPairDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    item_image
  end

  private

  # Determine the icon
  def item_image
    '100/auth_key_pair'
  end
end
