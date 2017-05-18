class RemoveRemoteApiSettings < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  API_AUTH_KEY = "/webservices/remote_miq_api%".freeze

  def up
    say_with_time("Removing configured API authentication") do
      SettingsChange.where("key LIKE ?", API_AUTH_KEY).delete_all
    end
  end
end
