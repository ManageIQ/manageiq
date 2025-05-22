# Reduce dev/test computational cost to authenticate users by using
# 4 (minimum) cost instead of 12 (default).
# See https://github.com/bcrypt-ruby/bcrypt-ruby/issues/180
unless Rails.env.production?
  ActiveSupport.on_load(:active_record) do
    require 'bcrypt'
    BCrypt::Engine.cost = 4
  end
end
