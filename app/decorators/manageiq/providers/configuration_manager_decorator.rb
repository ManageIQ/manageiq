module ManageIQ::Providers
  class ConfigurationManagerDecorator < Draper::Decorator
    delegate_all

    def fonticon
      nil
    end

    def listicon_image
      "100/vendor-#{image_name.downcase}.png"
    end

    def quadicon
      Quadicons::ConfigurationManagerQuadicon
    end
  end
end
