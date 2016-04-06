module ManageIQ::Providers::Hawkular
  class MiddlewareManagerDecorator < Draper::Decorator
    def fonticon
      nil
    end

    def listicon_image
      'vendor-hawkular'
    end
  end
end
