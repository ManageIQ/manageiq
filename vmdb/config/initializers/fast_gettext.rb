FastGettext.add_text_domain('manageiq', :path => "#{Rails.root}/config/locales", :type => :yaml)
FastGettext.default_available_locales = ['en']
FastGettext.default_text_domain = 'manageiq'
