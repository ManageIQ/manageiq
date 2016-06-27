describe 'miq_capacity/_bottlenecks_options.html.haml' do
  before :each do
    set_controller_for_view('miq_capacity')
  end

  it 'does not render Show Host Events checkbox under Datastores' do
    assign(:sb, :bottlenecks => {
                  :groups     => %w(Capacity Utilization),
                  :tl_options => {:filter1 => 'ALL'}})
    render :partial => 'miq_capacity/bottlenecks_options', :locals  => {:typ => 'summ', :x_node => 'ds_10r6'}
    expect(rendered).not_to have_selector('label', :text => 'Show Host Events')
  end
end
