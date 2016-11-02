class AssignedServerRoleDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    if active? && miq_server.started?
      "100/on.png"
    elsif miq_server.started?
      "100/suspended.png"
    else
      "100/off.png"
    end
  end
end
