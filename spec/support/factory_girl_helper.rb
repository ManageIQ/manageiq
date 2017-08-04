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

require 'factory_girl'
# in case we are running as an engine, the factories are located in the dummy app
FactoryGirl.definition_file_paths << 'spec/manageiq/spec/factories'

ENGINE_NAMESPACES_FOR_LOADING_FACTORIES = %w(
  ManageIQ::Providers
  ManageIQ::Consumption
).freeze

# also add factories from provider gems until miq codebase does not use any provider specific factories anymore
Rails::Engine.subclasses.select { |e| ENGINE_NAMESPACES_FOR_LOADING_FACTORIES.any? { |x| e.name.starts_with?(x) } }.each do |engine|
  FactoryGirl.definition_file_paths << File.join(engine.root, 'spec', 'factories')
end
FactoryGirl.find_definitions
