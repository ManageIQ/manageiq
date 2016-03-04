Rails.application.config.to_prepare do
  Vmdb::Productization.new.prepare
end
