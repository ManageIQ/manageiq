FastGettext.add_text_domain('manageiq', :path => Rails.root.join("config/locales"), :type => :po)
FastGettext.default_available_locales = %w(en hu it nl)
FastGettext.default_text_domain = 'manageiq'
