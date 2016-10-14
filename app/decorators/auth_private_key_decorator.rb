class AuthPrivateKeyDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "100/#{item_image}.png"
  end

  private

  def item_image
    'auth_key_pair'
  end
end
