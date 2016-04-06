class CreateGitRepositories < ActiveRecord::Migration[5.0]
  def change
    create_table :git_repositories do |t|
      t.string    :name
      t.string    :url
      t.timestamp :last_refresh_on
      t.integer   :verify_ssl

      t.timestamps
    end
  end
end
