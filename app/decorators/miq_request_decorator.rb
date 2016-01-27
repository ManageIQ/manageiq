class MiqRequestDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    case request_status.to_s.downcase
    when "ok"
      "100/checkmark.png"
    when "error"
      "100/x.png"
    # else - handled in application controller
    #  "100/#{@listicon.downcase}.png"
    end
  end
end
