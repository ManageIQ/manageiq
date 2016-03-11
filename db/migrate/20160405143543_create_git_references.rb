class CreateGitReferences < ActiveRecord::Migration[5.0]
  def change
    create_table :git_references do |t|
      t.string :name
      t.string :commit_sha
      t.timestamp :commit_time
      t.text :commit_message
      t.string :type
      t.bigint :git_repository_id

      t.timestamps
    end
  end
end
