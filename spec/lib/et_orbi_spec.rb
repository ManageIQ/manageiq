RSpec.describe EtOrbi do
  it '#can add times' do
    eot = EtOrbi::EoTime.new(0, 'Europe/Moscow')
    eot + 1.hour
  end
end
