class SetupCitextExtension < ActiveRecord::Migration[5.0]
  def up
    enable_extension 'citext'
  end

  def down
    disable_extension 'citext'
  end
end
