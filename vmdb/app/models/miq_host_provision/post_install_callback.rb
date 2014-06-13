module MiqHostProvision::PostInstallCallback
  extend ActiveSupport::Concern

  def provision_completed
    signal :post_install_callback
  end
end
