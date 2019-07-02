module ExternalUrlMixin
  extend ActiveSupport::Concern

  included do
    has_many :external_urls, :as => :resource, :dependent => :destroy
  end

  def external_url=(url, user = User.current_user)
    external_urls.where(:user => user).destroy_all
    external_urls.create!(:url => url, :user => user)
  end
end
