class ChangeOptionsInMiqAlert < ActiveRecord::Migration
  class MiqAlert < ActiveRecord::Base
    serialize :options
  end

  def up
    say_with_time("Replacing instances of 'alert@manageiq.com' from canned Alerts with ''") do
      MiqAlert.all.each do |a|
        value = a.options
        email_to = [:notifications, :email, :to]
        if value.fetch_path(email_to) == ['alert@manageiq.com']
          value.store_path(email_to, '')
          a.save
        end
      end
    end
  end
end
