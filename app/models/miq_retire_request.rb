class MiqRetireRequest < MiqRequest

  validates :request_state, :inclusion => { :in => %w(pending finished) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished" }
  validate :must_have_user

  default_value_for(:source_id)    { |r| r.get_option(:src_id) }

  def my_zone
  end
end
