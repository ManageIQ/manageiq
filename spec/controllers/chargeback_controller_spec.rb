require "spec_helper"

describe ChargebackController do
  before(:each) do
    set_user_privileges
  end

  context "returns current rate assignments or set them to blank if category/tag is deleted" do
    before(:each) do
      @category = FactoryGirl.create(:classification, :description => "Environment", :name => "environment")
      @tag = FactoryGirl.create(:classification,
                                :description => "Test category",
                                :name        => "test_category",
                                :parent_id   => @category.id)
      options = {:parent_id => @tag.id, :name => "test_entry", :description => "Test entry under test category"}
      @entry = FactoryGirl.create(:classification, options)
      cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "Storage")
      temp = {:cb_rate => cbr, :tag => [@tag, "vm"]}
      ChargebackRate.set_assignments(:Storage, [temp])
    end

    context "#get_tags_all" do
      it "returns the classification entry record" do
        controller.instance_variable_set(:@edit, :cb_assign => {:tags => {}})
        controller.send(:get_tags_all, @tag.id)
        assigns(:edit)[:cb_assign][:tags].should eq(@entry.id.to_s => @entry.description)
      end

      it "returns empty hash when classification entry is not found" do
        controller.instance_variable_set(:@edit, :cb_assign => {:tags => {}})
        controller.send(:get_tags_all, 1)
        assigns(:edit)[:cb_assign][:tags].should eq({})
      end
    end

    context "#cb_assign_set_form_vars" do
      it "returns tag for current assignments" do
        controller.instance_variable_set(:@sb,
                                         :active_tree => :cb_assignments_tree,
                                         :trees       => {:cb_assignments_tree => {:active_node => 'xx-Storage'}})
        controller.send(:cb_assign_set_form_vars)
        tag = assigns(:edit)[:current_assignment][0][:tag][0]
        tag['parent_id'].should eq(@category.id)
      end

      it "returns empty array for current_assignment when tag/category is not found" do
        @tag.destroy
        controller.instance_variable_set(:@sb,
                                         :active_tree => :cb_assignments_tree,
                                         :trees       => {:cb_assignments_tree => {:active_node => 'xx-Storage'}})
        controller.send(:cb_assign_set_form_vars)
        assigns(:edit)[:current_assignment].should eq([])
      end
    end
  end

  context "Saved chargeback rendering" do
    it "Saved chargeback reports renders paginagion buttons correctly" do
      report = FactoryGirl.create(:miq_report_with_results)
      report.extras = {:total_html_rows => 100}
      rp_id = report.id
      rr_id = report.miq_report_results[0].id
      node = "xx-#{rp_id}-2_rr-#{rr_id}"
      html = '<table><thead><tr><th>column 1</th><th>column 2</th></thead><tbody>'
      100.times do
        html += '<tr><td>col1 value</td><td>col2 value</td></tr>'
      end
      html += '</tbody></table>'

      controller.stub(:cb_rpts_show_saved_report)
      controller.should_receive(:render)
      controller.instance_variable_set(:@sb,
                                       :active_tree => :cb_reports_tree,
                                       :trees       => {:cb_reports_tree => {:active_node => node}})
      controller.instance_variable_set(:@report, report)
      controller.instance_variable_set(:@html, html)
      controller.instance_variable_set(:@layout, "chargeback")
      controller.instance_variable_set(:@_params, :id => node)
      controller.send(:tree_select)
      response.should render_template('layouts/_saved_report_paging_bar')
      controller.send(:flash_errors?).should_not be_true
      expect(response.status).to eq(200)
    end
  end

  render_views

  context "#explorer" do
    before(:each) do
      session[:settings] = {}
    end

    it 'can render the explorer' do
      get :explorer
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end
  end
end
