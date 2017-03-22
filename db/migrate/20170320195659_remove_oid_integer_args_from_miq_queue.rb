class RemoveOidIntegerArgsFromMiqQueue < ActiveRecord::Migration[5.0]
  class MiqQueue < ActiveRecord::Base; end
  def up
    say_with_time("Removing MiqQueue rows with args column values containing a class removed from Rails 5: PostgreSQL::OID::Integer.") do
      MiqQueue.where("args LIKE '%PostgreSQL::OID::Integer%'").delete_all
    end
  end
end
