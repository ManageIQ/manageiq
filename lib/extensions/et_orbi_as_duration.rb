module EtOrbiAsDuration
  def inc(t, dir = 1)
    t = t.to_i if t.kind_of?(ActiveSupport::Duration)
    super(t, dir)
  end
end

require 'et-orbi'
EtOrbi::EoTime.prepend(EtOrbiAsDuration)

if Gem::Version.new(EtOrbi::VERSION) > "1.2.11"
  warn "EtOrbiAsDuration monkey patch may no longer be necessary"
end
