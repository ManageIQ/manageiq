class AddDetailsToSystemConsoles < ActiveRecord::Migration[5.0]
  def change
    add_column :system_consoles, :url, :string
    add_column :system_consoles, :proxy_pid, :integer
    add_column :system_consoles, :proxy_status, :string
  end
end
