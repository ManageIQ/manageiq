describe ReportController do
  render_views
  before :each do
    set_user_privileges
    EvmSpecHelper.create_guid_miq_server_zone
  end

  context 'Reports #tree_select' do
    before do
      session[:settings] = {}
    end

    context "saved reports tree" do
      before do
        seed_session_trees('savedreports', :savedreports_tree)
      end

      it 'renders list' do
        post :tree_select, :params => { :id => 'root', :format => :js, :accord => 'savedreports' }
        expect(response).to render_template('report/_savedreports_list')
      end

      it 'renders show' do
        user = FactoryGirl.create(:user_with_group)
        login_as user
        controller.instance_variable_set(:@html, "<h1>Test</h1>")
        allow(controller).to receive(:report_first_page)
        report = FactoryGirl.create(:miq_report_with_results)
        allow(report).to receive(:contains_records?).and_return(true)
        task = FactoryGirl.create(:miq_task)
        task.update_attributes(:state => "Finished")
        task.reload
        report_result = FactoryGirl.create(:miq_report_result,
                                           :miq_group_id => user.current_group.id,
                                           :miq_task_id  => task.id)
        allow_any_instance_of(MiqReportResult).to receive(:report_results).and_return(report)
        binary_blob = FactoryGirl.create(:binary_blob,
                                         :resource_type => "MiqReportResult",
                                         :resource_id   => report_result.id)
        FactoryGirl.create(:binary_blob_part,
                           :data           => "--- Quota \xE2\x80\x93 Max CPUs\n...\n",
                           :binary_blob_id => binary_blob.id)

        post :tree_select, :params => { :id => "rr-#{report_result.id}", :format => :js, :accord => 'savedreports' }
        expect(response).to render_template('shared/_report_chart_and_html')
      end
    end

    context "reports tree" do
      before do
        seed_session_trees('report', :reports_tree)
      end

      it 'renders list of Reports in Reports - Custom tree' do
        FactoryGirl.create(:miq_report)
        post :tree_select, :params => { :id => 'reports_xx-0', :format => :js }
        expect(response).to render_template('report/_report_list')
      end
    end

    context "schedules tree" do
      before do
        seed_session_trees('schedules', :schedules_tree)
      end

      it 'renders list of Schedules in Schedules tree' do
        post :tree_select, :params => { :id => 'root', :format => :js, :accord => 'schedules' }
        expect(response).to render_template('report/_schedule_list')
      end

      it 'renders show of Schedule in Schedules tree' do
        schedule = FactoryGirl.create(:miq_schedule)
        post :tree_select, :params => { :id => "msc-#{schedule.id}", :format => :js, :accord => 'schedules' }
        expect(response).to render_template('report/_show_schedule')
      end
    end

    context "dashboards tree" do
      before do
        seed_session_trees('db', :db_tree)
      end

      it 'renders list of Dashboards in Dashboards tree' do
        MiqWidgetSet.seed
        post :tree_select, :params => { :id => 'root', :format => :js, :accord => 'db' }
        expect(response).to render_template('report/_db_list')
      end

      it 'renders show of Dashboards in Dashboards tree' do
        ApplicationController.handle_exceptions = true

        MiqWidgetSet.seed
        user = FactoryGirl.create(:user_with_group)
        login_as user
        widget_set = FactoryGirl.create(:miq_widget_set, :group_id => user.current_group.id)
        post :tree_select, :params => { :id => "xx-g_g-#{user.current_group.id}_-#{widget_set.id}", :format => :js, :accord => 'db' }
        expect(response).to render_template('report/_db_show')
      end
    end

    context "dashboard widgets tree" do
      before do
        seed_session_trees('widgets', :widgets_tree)
      end

      it 'renders list of Dashboard Widgets in Widgets tree' do
        post :tree_select, :params => { :id => 'root', :format => :js, :accord => 'widgets' }
        expect(response).to render_template('report/_widget_list')
      end

      it 'renders show of Dashboard Widget in Widgets tree' do
        ApplicationController.handle_exceptions = true

        widget = FactoryGirl.create(:miq_widget)
        post :tree_select, :params => { :id => "xx-r_-#{widget.id}", :format => :js, :accord => 'widgets' }
        expect(response).to render_template('report/_widget_show')
      end
    end

    context "role menus tree" do
      before do
        seed_session_trees('roles', :roles_tree)
      end

      it 'renders list of Roles in Roles tree' do
        login_as (FactoryGirl.create(:user_with_group))
        post :tree_select, :params => { :id => 'root', :format => :js, :accord => 'roles' }
        expect(response).to render_template('report/_role_list')
      end

      it 'renders form to edit Role in Roles tree' do
        FactoryGirl.create(:miq_report)
        user = FactoryGirl.create(:user_with_group)
        login_as user
        post :tree_select, :params => { :id => "g-#{user.current_group.id}", :format => :js, :accord => 'roles' }
        expect(response).to render_template('report/_menu_form1')
      end
    end
    after do
      expect(response.status).to eq(200)
    end
  end
end
