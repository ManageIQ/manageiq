class MiqServersFilter
  def filter_conditions
    # NOTE: PostgreSQL specific condition
    {
      :replicate => {
        :update => 'NEW."last_heartbeat" != OLD."last_heartbeat"'
      }
    }
  end
end
