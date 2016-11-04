describe "miq_policy/_alert_details.html.haml" do
  before do
    @alert = FactoryGirl.create(:miq_alert)
    @alert_profiles = Object.new
    exp = {:eval_method => 'nothing', :mode => 'internal', :options => {}}
    allow(@alert).to receive(:expression).and_return(exp)
    set_controller_for_view("miq_policy")
  end

  it "Trap Number is displayed correctly" do
    opts = {:notifications => {:snmp => {:host => ['test.test.org'], :snmp_version => 'v1', :trap_id => '42'}}}
    allow(@alert).to receive(:options).and_return(opts)
    allow(@alert_profiles).to receive(:empty?).and_return(true)
    render :partial => 'miq_policy/alert_details',
           :locals  => {:x_active_tree => :alert_tree}
    expect(rendered).to include('Trap Number')
  end
end
