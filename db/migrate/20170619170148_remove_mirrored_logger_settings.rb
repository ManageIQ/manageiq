class RemoveMirroredLoggerSettings < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
  end

  def up
    say_with_time("Remove MirroredLogger settings") do
      SettingsChange.where("key LIKE ?", "/log/level_%_in_evm").delete_all
    end
  end
end
