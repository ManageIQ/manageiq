Rails.application.routes.draw do
  mount ProviderAmazon::Engine => "/provider_amazon"
end
