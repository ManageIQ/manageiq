describe ReportController do
  context "::Reports::Editor" do
    context "#set_form_vars" do
      let(:user) { stub_user(:features => :all) }

      let(:chargeback_report) do
        FactoryGirl.create(:miq_report,
          :db         => "ChargebackVm",
          :name       => 'name',
          :title      => 'title',
          :db_options => {:options => {:owner => user.userid}},
          :col_order  => ["name"],
          :headers    => ["Name"],
          :tz         => nil
        )
      end

      let(:report_edit_options) do
        {
          :rpt_id  => chargeback_report.id,
          :new     => {
            :model  => "ChargebackVm",
            :name   => 'name',
            :title  => 'title',
            :tz     => "Eastern Time (US & Canada)",
            :fields => []
          },
          :current => {}
        }
      end

      before do
        allow(User).to receive(:server_timezone).and_return("UTC")

        allow(controller).to receive(:check_privileges).and_return(true)
        allow(controller).to receive(:load_edit).and_return(true)
        allow(controller).to receive(:valid_report?).and_return(true)
        allow(controller).to receive(:x_node).and_return("")
        allow(controller).to receive(:gfv_sort)
        allow(controller).to receive(:build_edit_screen)
        allow(controller).to receive(:get_all_widgets)
        allow(controller).to receive(:replace_right_cell)
      end

      it "check existence of cb_owner_id key" do
        controller.instance_variable_set(:@rpt, chargeback_report)
        controller.send(:set_form_vars)
        new_hash = assigns(:edit)[:new]
        expect(new_hash).to have_key(:cb_owner_id)
        expect(new_hash[:cb_owner_id]).to eq(user.userid)
      end

      it "should save the selected tim e zone with a chargeback report" do
        ApplicationController.handle_exceptions = true

        controller.instance_variable_set(:@edit, report_edit_options)
        session[:edit] = assigns(:edit)

        post :miq_report_edit, :params => { :id => chargeback_report.id, :button => 'save' }

        chargeback_report.reload

        expect(chargeback_report.tz).to eq("Eastern Time (US & Canada)")
      end

      it "should save the 'Tag Group' option" do
        ApplicationController.handle_exceptions = true

        report_edit_options[:new][:cb_groupby] = "tag"
        report_edit_options[:new][:cb_groupby_tag] = "department"
        report_edit_options[:cb_cats] = {'department' => 'Department'}

        controller.instance_variable_set(:@edit, report_edit_options)
        session[:edit] = assigns(:edit)

        post :miq_report_edit, :params => { :id => chargeback_report.id, :button => 'save' }

        chargeback_report.reload
        expect(chargeback_report.db_options[:options][:groupby_tag]).to eq('department')
      end

      describe '#reportable_models' do
        subject { controller.send(:reportable_models) }
        it 'does not contain duplicate items' do
          duplicates = subject.group_by(&:first).select { |_, v| v.size > 1 }.map(&:first)
          expect(duplicates).to be_empty
        end
      end
    end

    context "#miq_report_edit" do
      before { stub_user(:features => :all) }

      it "should build tabs with correct tab id after reset button is pressed to prevent error when changing tabs" do
        ApplicationController.handle_exceptions = true

        rep = FactoryGirl.create(
          :miq_report,
          :rpt_type   => "Custom",
          :db         => "Host",
          :name       => 'name',
          :title      => 'title',
          :db_options => {},
          :col_order  => ["name"],
          :headers    => ["Name"],
          :tz         => nil
        )

        edit = {
          :rpt_id  => rep.id,
          :new     => {
            :model  => "Host",
            :name   => 'name',
            :title  => 'title',
            :tz     => "test",
            :fields => []
          },
          :current => {}
        }

        controller.instance_variable_set(:@edit, edit)
        session[:edit] = assigns(:edit)

        allow(controller).to receive(:load_edit).and_return(true)

        allow(controller).to receive(:replace_right_cell)

        post :miq_report_edit, :params => { :id => rep.id, :button => 'reset' }
        expect(assigns(:sb)[:miq_tab]).to eq("edit_1")
        expect(assigns(:tabs)).to include(["edit_1", "Columns"])
        expect(assigns(:active_tab)).to eq("edit_1")
      end
    end

    describe "set_form_vars" do
      let(:admin_user) { FactoryGirl.create(:user, :role => "super_administrator") }
      let(:chargeback_report) do
        FactoryGirl.create(:miq_report, :db => "ChargebackVm", :col_order => ["name"], :headers => ["Name"])
      end

      let(:fake_id) { 999_999_999 }

      before do
        login_as admin_user
        controller.instance_variable_set(:@rpt, chargeback_report)
        @edit_form_vars = {}
        @edit_form_vars[:new] = {}
        @edit_form_vars[:new][:name] = chargeback_report.name
        @edit_form_vars[:new][:model] = chargeback_report.db
        @edit_form_vars[:new][:fields] = []
      end

      it "sets proper UI var(cb_show_typ) for chargeback filters in chargeback report" do
        %w(owner tenant tag entity).each do |show_typ|
          chargeback_report.db_options = {}
          chargeback_report.db_options[:options] = {}

          case
          when show_typ == "owner"
            chargeback_report.db_options[:options] = {:owner => fake_id}
          when show_typ == "tenant"
            chargeback_report.db_options[:options] = {:tenant_id => fake_id}
          when show_typ == "tag"
            chargeback_report.db_options[:options] = {:tag => "/managed/prov_max_cpu/1"}
          when show_typ == "entity"
            chargeback_report.db_options[:options] = {:provider_id => fake_id, :entity_id => fake_id}
          end

          controller.instance_variable_set(:@rpt, chargeback_report)
          controller.send(:set_form_vars)

          displayed_edit_form = assigns(:edit)[:new]
          expect(displayed_edit_form[:cb_show_typ]).to eq(show_typ)
        end
      end
    end

    def non_empty_category(attrs = {})
      cat = FactoryGirl.create(:classification, :name => "non_empty", :description => "Has entries", **attrs)
      cat.add_entry(:name => "foo", :description => "Foo")
      cat.add_entry(:name => "bar", :description => "Bar")
      cat
    end

    def empty_category(attrs = {})
      FactoryGirl.create(:classification, :name => "empty", :description => "Zero entries", **attrs)
    end

    describe "#categories_hash" do
      it "returns non-empty categories" do
        non_empty_category
        empty_category
        expect(controller.send(:categories_hash)).to eq("non_empty" => "Has entries")
      end

      it "omits show: false categories" do
        non_empty_category(:show => false)
        expect(controller.send(:categories_hash)).to eq({})
      end

      it "includes read_only categories" do
        non_empty_category(:read_only => true)
        expect(controller.send(:categories_hash)).to eq("non_empty" => "Has entries")
      end
    end

    describe "#entries_hash" do
      it "returns entries" do
        non_empty_category
        expect(controller.send(:entries_hash, "non_empty")).to eq("foo" => "Foo",
                                                                  "bar" => "Bar")
      end

      it "returns {} given invalid category name" do
        expect(controller.send(:entries_hash, "no_such_name")).to eq({})
      end
    end
  end

  describe '#verify is_valid? flash messages' do
    it 'show flash message when show cost by entity is selected but no entity_id chosen' do
      model = 'ChargebackContainerProject'
      controller.instance_variable_set(:@edit, :new => {:model       => model,
                                                        :fields      => [['Date Created']],
                                                        :cb_show_typ => 'entity',
                                                        :cb_model    => 'ContainerProject'})
      controller.instance_variable_set(:@sb, {})
      rpt = FactoryGirl.create(:miq_report_chargeback)
      controller.send(:valid_report?, rpt)
      flash_messages = assigns(:flash_array)
      flash_str = 'A specific Project or all must be selected'
      expect(flash_messages.first[:message]).to eq(flash_str)
      expect(flash_messages.first[:level]).to eq(:error)
    end
  end

  tabs = {:formatting => 2, :filter => 3, :summary => 4, :charts => 5, :timeline => 6, :preview => 7,
          :consolidation => 8, :styling => 9}
  chargeback_tabs = [:formatting, :filter, :preview]

  describe '#build_edit_screen' do
    let(:user) { FactoryGirl.create(:user) }
    let(:chargeback_report) do
      FactoryGirl.create(:miq_report, :db => 'ChargebackVm', :db_options => {:options => {:owner => user.userid}},
                                    :col_order => ['name'], :headers => ['Name'])
    end

    before { login_as user }

    tabs.slice(*chargeback_tabs).each do |tab_number|
      it 'flash messages should be nil' do
        controller.instance_variable_set(:@rpt, chargeback_report)
        controller.send(:set_form_vars)
        controller.instance_variable_set(:@sb, :miq_tab => "edit_#{tab_number.second}")
        controller.send(:build_edit_screen)

        expect(assigns(:flash_array)).to be_nil
      end
    end
  end

  describe '#check_tabs' do
    tabs.each_pair do |tab_title, tab_number|
      title = tab_title.to_s.titleize
      it "check existence of flash message when tab is changed to #{title} without selecting fields" do
        controller.instance_variable_set(:@sb, {})
        controller.instance_variable_set(:@edit, :new => {:fields => []})
        controller.instance_variable_set(:@_params, :tab => "new_#{tab_number}")
        controller.send(:check_tabs)
        flash_messages = assigns(:flash_array)
        flash_str = "#{title} tab is not available until at least 1 field has been selected"
        expect(flash_messages.first[:message]).to eq(flash_str)
        expect(flash_messages.first[:level]).to eq(:error)
      end

      it "flash messages should be nil when tab is changed to #{title} after selecting fields" do
        controller.instance_variable_set(:@sb, {})
        controller.instance_variable_set(:@edit, :new => {
                                           :fields  => [['Date Created', 'Vm-ems_created_on']],
                                           :sortby1 => 'some_field'
                                         })
        controller.instance_variable_set(:@_params, :tab => "new_#{tab_number}")
        controller.send(:check_tabs)
        expect(assigns(:flash_array)).to be_nil
      end
    end

    it 'check existence of flash message when tab is changed to preview without selecting filters(chargeback report)' do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@edit, :new => {:fields => [['Date Created']], :model => 'ChargebackVm'})
      controller.instance_variable_set(:@_params, :tab => 'new_7') # preview
      controller.send(:check_tabs)
      flash_messages = assigns(:flash_array)
      expect(flash_messages).not_to be_nil
      flash_str = 'Preview tab is not available until Chargeback Filters has been configured'
      expect(flash_messages.first[:message]).to eq(flash_str)
      expect(flash_messages.first[:level]).to eq(:error)
    end
  end
end
