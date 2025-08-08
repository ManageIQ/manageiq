RSpec.describe EtOrbi do
  # this was a patch. verifying that we no longer need the patch
  it "can add ActiveSupport::Duration to EtOrbi::EoTime" do
    eot = EtOrbi::EoTime.new(0, 'Europe/Moscow')
    expect(eot + 1.hour).to eq(EtOrbi::EoTime.new(3600, 'Europe/Moscow'))
  end
end
