class RefreshQueue < ApplicationRecord
  class << self
    def enqueue!(persister)
      create!(:class_name => persister.class.name, :persister_data => persister.send(:to_hash))
    end

    def dequeue!
      # TODO add zone, server id, etc
      query = <<-SQL
       DELETE FROM refresh_queue
         WHERE ctid IN (
             SELECT ctid
             FROM refresh_queue
             ORDER BY created_on ASC
             LIMIT 1
         )
         RETURNING *
      SQL

      item = connection.execute(query).try(:first)
      return unless item

      item["class_name"].safe_constantize.from_json(item["persister_data"])
    end
  end
end
