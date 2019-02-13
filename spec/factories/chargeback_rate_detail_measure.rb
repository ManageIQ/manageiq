FactoryBot.define do
  factory :chargeback_rate_detail_measure do
    step  { "1024" }
    name { "Bytes Units" }
    units_display { %w(B KB MB GB TB) }
    units { %w(bytes kilobytes megabytes gigabytes terabytes) }
  end

  factory :chargeback_measure_bytes, :parent => :chargeback_rate_detail_measure

  factory :chargeback_measure_hz, :parent => :chargeback_rate_detail_measure do
    name { 'Hz Units' }
    step { '1000' }
    units_display { %w(Hz KHz MHz GHz THz) }
    units { %w(hertz kilohertz megahertz gigahertz teraherts) }
  end

  factory :chargeback_measure_bps, :parent => :chargeback_rate_detail_measure do
    name { 'Bytes per Second Units' }
    step { '1000' }
    units_display { %w(Bps KBps MBps GBps) }
    units { %w(bps kbps mbps gbps) }
  end
end
