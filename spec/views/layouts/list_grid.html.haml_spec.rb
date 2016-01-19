describe "layouts/_list_grid.html.haml" do
  context "when showtype is 'performance'" do
    it "renders" do
      allow(view).to receive(:options).and_return({:grid_hash => {:head => [], :rows => []}})
      allow(view).to receive(:js_options).and_return({:row_url => '_none_'})
      record = EmsInfra.new(:id => 1)
      assign(:parent, record)
      render
    end
  end

  it "has valid links for row clicks" do
    options = {:grid_id => 'list_grid', :grid_name => 'gtl_list_grid',

                :grid_hash => {:head => [{:is_narrow => true}, {:is_narrow => true},
                                         {:text => 'Name', :sort => 'str', :col_idx => 0, :align => 'left'},
                                         {:text => 'Description', :sort => 'str', :col_idx => 0, :align => 'left'},
                                         {:text => 'Type', :sort => 'str', :col_idx => 0, :align => 'left'},
                                         {:text => 'Display in Catalog', :sort => 'str', :col_idx => 0, :align => 'left'},
                                         {:text => 'Catalog', :sort => 'str', :col_idx => 0, :align => 'left'},
                                         {:text => 'Created On', :sort => 'str', :col_idx => 0, :align => 'left'}],
                               :rows => [{:id => '10r96',
                                          :cells => [{:is_checkbox => true},
                                                     {:tile => 'View this item', :image => '/pictures/10r33.png'},
                                                     {:text => 'abcd'}, {:text => 'abcd'}, {:text => 'Item'},
                                                     {:text => 'Yes'}, {:text => ''},
                                                     {:text => '01/10/16 22:30:00 UTC'}]
                                         },
                                         {:id => '10r28',
                                          :cells => [{:is_checkbox => true},
                                                     {:tile => 'View this item', :image => '/pictures/10r33.png'},
                                                     {:text => 'efgh'}, {:text => 'efgh'}, {:text => 'Item'},
                                                     {:text => 'Yes'}, {:text => ''},
                                                     {:text => '01/08/16 20:30:00 UTC'}]
                                         }]},
                :button_div => 'center_tb', :action_url => 'explorer'}
    js_options = {:sortcol => 0, :sortdir => 'ASC', :row_url => '/catalog/x_show/', :row_url_ajax => true}
    render :partial => "layouts/list_grid", :locals => {:options => options, :js_options => js_options}
    expect(response).to include("<tr onclick='miqRowClick(&#39;10r96&#39;, &#39;/catalog/x_show/&#39;, true); return false;'>")
  end
end
