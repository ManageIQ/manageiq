def toggle_on_name_seq(seq)
  seq.name.split("_").last.to_i % 2 != 0
end

def ip_from_seq(seq)
  ip = 0xFFFFFFFF - seq
  "#{ip >> 24}.#{ip >> 16 & 0xFF}.#{ip >> 8 & 0xFF}.#{ip & 0xFF}"
end

def mac_from_seq(seq)
  ip = (0xFFFFFFFFFFFF - seq).to_s(16)
  [10, 8, 6, 4, 2].each { |i| ip.insert(i, ':') }
  ip
end

require 'factory_girl'
FactoryGirl.find_definitions
