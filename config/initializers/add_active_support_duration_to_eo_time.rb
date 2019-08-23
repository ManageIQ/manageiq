module AddActiveSupportDurationToEoTime
  def inc(t, dir = 1)
    t = t.to_i if t.kind_of?(ActiveSupport::Duration)
    super(t, dir)
  end
end

require 'et-orbi'
EtOrbi::EoTime.prepend(AddActiveSupportDurationToEoTime)
