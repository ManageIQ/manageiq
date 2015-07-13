# https://github.com/thoughtbot/paperclip/issues/1335
# work around paperclip not supporting asset pipeline in model
Paperclip.interpolates :default_login_logo do |_attachment, _style|
  ActionController::Base.helpers.asset_path('login-screen-logo.png')
end
