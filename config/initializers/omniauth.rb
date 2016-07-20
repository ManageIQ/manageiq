if ENV["GOOGLE_CLIENT_SECRET"]
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"],
             :scope => 'https://www.googleapis.com/auth/compute,' \
               'https://www.googleapis.com/auth/devstorage.read_only,' \
               'https://www.googleapis.com/auth/logging.write,' \
               'https://www.googleapis.com/auth/cloud-platform,' \
               'email,profile'
  end
end
