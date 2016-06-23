module ManageIQ::Providers::Hawkular
  class MiddlewareManagerDecorator < Draper::Decorator
    def fonticon
      nil
    end

    def listicon_image
      "svg/#{item_image}.svg"
    end

    def item_image
      'vendor-hawkular'
    end
  end
end
