describe ChargebackController do
  before { set_user_privileges }

  context "returns current rate assignments or set them to blank if category/tag is deleted" do
    let(:category) { FactoryGirl.create(:classification) }
    let(:tag)      { FactoryGirl.create(:classification, :parent_id => category.id) }
    let(:entry)    { FactoryGirl.create(:classification, :parent_id => tag.id) }

    context "#get_tags_all" do
      before { entry }

      it "returns the classification entry record" do
        controller.instance_variable_set(:@edit, :cb_assign => {:tags => {}})
        controller.send(:get_tags_all, tag.id)
        expect(assigns(:edit)[:cb_assign][:tags]).to eq(entry.id.to_s => entry.description)
      end

      it "returns empty hash when classification entry is not found" do
        controller.instance_variable_set(:@edit, :cb_assign => {:tags => {}})
        controller.send(:get_tags_all, 1)
        expect(assigns(:edit)[:cb_assign][:tags]).to eq({})
      end
    end

    context "#cb_assign_set_form_vars" do
      before do
        cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "Storage")
        ChargebackRate.set_assignments(:Storage, [{:cb_rate => cbr, :tag => [tag, "vm"]}])
        sandbox = {:active_tree => :cb_assignments_tree, :trees => \
          {:cb_assignments_tree => {:active_node => 'xx-Storage'}}}
        controller.instance_variable_set(:@sb, sandbox)
      end

      it "returns tag for current assignments" do
        controller.send(:cb_assign_set_form_vars)
        expect(assigns(:edit)[:current_assignment][0][:tag][0]['parent_id']).to eq(category.id)
      end

      it "returns empty array for current_assignment when tag/category is not found" do
        tag.destroy
        controller.send(:cb_assign_set_form_vars)
        expect(assigns(:edit)[:current_assignment]).to eq([])
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

      allow(controller).to  receive(:cb_rpts_show_saved_report)
      expect(controller).to receive(:render)
      controller.instance_variable_set(:@sb,
                                       :active_tree => :cb_reports_tree,
                                       :trees       => {:cb_reports_tree => {:active_node => node}})
      controller.instance_variable_set(:@report, report)
      controller.instance_variable_set(:@html, html)
      controller.instance_variable_set(:@layout, "chargeback")
      controller.instance_variable_set(:@_params, :id => node)
      controller.send(:tree_select)
      expect(response).to                        render_template('layouts/_saved_report_paging_bar')
      expect(controller.send(:flash_errors?)).to be_falsey
      expect(response.status).to                 eq(200)
    end
  end

  context "#explorer" do
    render_views

    it "can be rendered" do
      EvmSpecHelper.create_guid_miq_server_zone
      get :explorer
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end
  end

  context "#process_cb_rates" do
    it "delete unassigned" do
      cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "Storage", :description => "Storage Rate")

      rates = [cbr.id]
      controller.send(:process_cb_rates, rates, "destroy")

      expect(controller.send(:flash_errors?)).to be_falsey

      flash_array = assigns(:flash_array)
      expect(flash_array.first[:message]).to include("Delete successful")
    end

    it "delete assigned" do
      cbr = FactoryGirl.create(:chargeback_rate, :rate_type => "Storage", :description => "Storage Rate")
      host = FactoryGirl.create(:host)
      cbr.assign_to_objects(host)

      rates = [cbr.id]
      controller.send(:process_cb_rates, rates, "destroy")

      expect(controller.send(:flash_errors?)).to be_truthy

      flash_array = assigns(:flash_array)
      expect(flash_array.first[:message]).to include("rate is assigned and cannot be deleted")
    end
  end
  context "#get_cis_all" do
    elements_miq = %w(enterprise storage ext_management_system ems_cluster tenants)
    elements_miq.each do |element|
      it "returns names of instances of " + element do
        names = {}
        classtype =
          if element == "enterprise"
            MiqEnterprise
          else
            element.classify.constantize
          end

        classtype.all.each do |instance|
          names[instance.id] = instance.name
        end
        controller.instance_variable_set(:@edit, :new => {:cbshow_typ => element}, :cb_assign => {})
        controller.send(:get_cis_all)
        expect(assigns(:edit)[:cb_assign][:cis]).to eq(names)
      end
    end
  end
end
