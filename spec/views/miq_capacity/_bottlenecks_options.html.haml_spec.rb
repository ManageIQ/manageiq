describe 'miq_capacity/_bottlenecks_options.html.haml' do
  before :each do
    set_controller_for_view('miq_capacity')
    assign(:sb, :bottlenecks => {:groups     => %w(Capacity Utilization),
                                 :tl_options => {:filter1 => 'ALL'}})
  end

  it 'does render Show Host Events checkbox under Datastores' do
    render :partial => 'miq_capacity/bottlenecks_options', :locals => {:typ => 'summ', :x_node => 'e_10r1'}
    expect(rendered).to have_selector('label', :text => 'Show Host Events')
  end

  it 'does not render Show Host Events checkbox under Datastores' do
    render :partial => 'miq_capacity/bottlenecks_options', :locals => {:typ => 'summ', :x_node => 'ds_10r6'}
    expect(rendered).not_to have_selector('label', :text => 'Show Host Events')
  end
end
