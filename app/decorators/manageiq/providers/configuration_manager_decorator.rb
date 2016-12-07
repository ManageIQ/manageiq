module ManageIQ::Providers
  class ConfigurationManagerDecorator < Draper::Decorator
    delegate_all

    def fonticon
      nil
    end

    def listicon_image
      "svg/vendor-#{image_name.downcase}.svg"
    end
  end
end
