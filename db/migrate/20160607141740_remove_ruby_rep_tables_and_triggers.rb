class RemoveRubyRepTablesAndTriggers < ActiveRecord::Migration[5.0]
  include MigrationHelper

  TRIGGER_QUERY = <<-SQL.freeze
    SELECT relname, array_agg(tgname) AS triggers
    FROM pg_trigger t
      JOIN pg_class c ON t.tgrelid = c.oid
    WHERE t.tgname LIKE 'rr%_%'
    GROUP BY relname
  SQL

  TABLE_QUERY = <<-SQL.freeze
    SELECT relname
    FROM pg_class
    WHERE relname LIKE 'rr%_pending_changes' OR
          relname LIKE 'rr%_logged_events' OR
          relname LIKE 'rr%_sync_state'
  SQL

  def up
    say_with_time("Dropping all rubyrep triggers") do
      connection.execute(TRIGGER_QUERY).each do |r|
        table = r["relname"]
        sql_array_to_ruby(r["triggers"]).each do |trigger|
          drop_trigger(table, trigger)
        end
      end
    end

    say_with_time("Removing rubyrep tables") do
      connection.execute(TABLE_QUERY).each { |r| drop_table(r["relname"]) }
    end
  end

  def sql_array_to_ruby(sql_arr)
    # the array is returned like: "{value1,value2,value3}"
    # so we cut out the brackets and split on commas
    sql_arr[1..-2].split(",")
  end
end
