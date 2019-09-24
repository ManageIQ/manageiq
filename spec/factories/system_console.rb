FactoryBot.define do
  factory(:system_console) do
    host_name { 'manageiq.org' }
    port { '80' }
    ssl { false }
    protocol { :vnc }
    secret { SecureRandom.base64[0, 8] }
    vm { nil }
    user { nil }
  end
end
