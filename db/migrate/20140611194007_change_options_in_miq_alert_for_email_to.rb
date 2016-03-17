class ChangeOptionsInMiqAlertForEmailTo < ActiveRecord::Migration
  class MiqAlert < ActiveRecord::Base
    serialize :options
  end

  def up
    say_with_time("Changing email-to list from string to array") do
      email_to_path = [:notifications, :email, :to]
      MiqAlert.all.each do |a|
        value = a.options
        email_to_str  = value.fetch_path(email_to_path)
        if email_to_str.kind_of? String
          value.store_path(email_to_path, email_to_str.lines.collect(&:chomp))
          a.save!
        end
      end
    end
  end
end
