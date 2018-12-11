def toggle_on_name_seq(seq)
  seq.name.split("_").last.to_i.odd?
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

def seq_padded_for_sorting(n)
  n.to_s.rjust(13, '0') # pad to 13 for max region size
end

require 'factory_bot'
FactoryGirl = FactoryBot # Alias until all associated repositories are updated

# In case we are running as an engine, the factories are located in the dummy app
FactoryBot.definition_file_paths << 'spec/manageiq/spec/factories'

# Also, add factories from provider gems until miq codebase does not use any provider specific factories anymore
Rails::Engine.subclasses.select { |e| e.name.starts_with?("ManageIQ::Providers") }.each do |engine|
  FactoryBot.definition_file_paths << File.join(engine.root, 'spec', 'factories')
end

FactoryBot.find_definitions
