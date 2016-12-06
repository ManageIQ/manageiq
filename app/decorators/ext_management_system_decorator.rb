class ExtManagementSystemDecorator < Draper::Decorator
  delegate_all

  def fonticon
    nil
  end

  def listicon_image
    "svg/vendor-#{image_name}.svg"
  end

  def quadicon_title_str
    "Name: %{name} | Hostname: %{hostname} | Refresh Status: %{status}"
  end

  def quadicon_title_hash
    {
      :name     => name,
      :hostname => hostname,
      :status   => last_refresh_status.titleize
    }
  end
end
