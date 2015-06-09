require "spec_helper"
include JsHelper

describe ApplicationHelper do
  context "build_custom_buttons_toolbar" do
    class Controller
      include ApplicationHelper

      attr_reader :request

      def initialize(sb, request)
        @sb      = sb
        @request = request
      end

      def role_allows(options)
        true
      end
    end

    it 'should substitute dynamic function values' do
      req        = ActionDispatch::Request.new Rack::MockRequest.env_for '/?controller=foo'
      controller = Controller.new({:active_tree => :cb_reports_tree}, req)
      json,      = controller.build_toolbar_buttons_and_xml 'storages_center_tb'
      title_text = ui_lookup(:tables => "storages")
      menu_info  = JSON.parse json

      menu_info.each_value do |value|
        %w( title confirm ).each do |field|
          if value[field]
            expect(value[field]).to match(title_text)
          end
        end
      end
    end

    it 'should substitute dynamic ivar values' do
      req = ActionDispatch::Request.new Rack::MockRequest.env_for '/?controller=foo'
      controller = Controller.new({:active_tree => :cb_reports_tree,
                                   :nodeid      => 'storages',
                                   :mode        => 'foo' }, req)

      json, = controller.build_toolbar_buttons_and_xml 'miq_policies_center_tb'
      title_text = ui_lookup(:model => "storages")

      menu_info = JSON.parse json
      menu_info.each_value do |value|
        next unless value['title']
        expect(value['title']).to match(title_text)
        expect(value['title']).to match("Foo") # from :mode
      end
    end
  end

  describe "#role_allows" do
    before(:each) do
      MiqRegion.seed
      EvmSpecHelper.seed_specific_product_features("miq_report", "service")

      @admin_role  = FactoryGirl.create(:miq_user_role, :name => "admin", :miq_product_features => MiqProductFeature.find_all_by_identifier(["everything"]))
      @admin_group = FactoryGirl.create(:miq_group, :miq_user_role => @admin_role)
      @user        = FactoryGirl.create(:user, :name => 'wilma', :miq_groups => [@admin_group])
      User.stub(:current_user => @user)
    end

    context "when with :feature" do
      context "and :any" do
        it "and entitled" do
          role_allows(:feature=>"miq_report", :any=>true).should be_true
        end

        it "and not entitled" do
          User.stub_chain(:current_user, :role_allows_any?).and_return(false)
          role_allows(:feature=>"miq_report", :any=>true).should be_false
        end
      end

      context "and no :any" do
        it "and entitled" do
          role_allows(:feature=>"miq_report").should be_true
        end

        it "and not entitled" do
          User.stub_chain(:current_user, :role_allows?).and_return(false)
          role_allows(:feature=>"miq_report").should be_false
        end
      end
    end

    context "when with :main_tab_id" do
      include UiConstants
      it "and entitled" do
        Menu::DefaultMenu.services_menu_section.visible?.should be_true
      end

      it "and not entitled" do
        User.stub_chain(:current_user, :role_allows_any?).and_return(false)
        Menu::DefaultMenu.services_menu_section.visible?.should be_false
      end
    end

    it "when not with :feature or :main_tab_id" do
      role_allows.should be_false
    end
  end

  describe "#model_to_controller" do
    subject { model_to_controller(@record) }

    it "when with any record" do
      @record = FactoryGirl.create(:vm_vmware)
      subject.should == @record.class.base_model.name.underscore
    end

    it "when record is nil" do
      lambda { model_to_controller(nil) }.should raise_error(NoMethodError)
    end
  end

  describe "#object_types_for_flash_message" do
    before do
      @record_1 = FactoryGirl.create(:vm_openstack, :type => "VmOpenstack",       :template => false )
      @record_2 = FactoryGirl.create(:vm_openstack, :type => "VmOpenstack",       :template => false )
      @record_3 = FactoryGirl.create(:vm_openstack, :type => "TemplateOpenstack", :template => true )
      @record_4 = FactoryGirl.create(:vm_openstack, :type => "TemplateOpenstack", :template => true )
      @record_5 = FactoryGirl.create(:vm_redhat,    :type => "VmRedhat")
      @record_6 = FactoryGirl.create(:vm_vmware,    :type => "VmVmware")
    end

    context "when formatting flash message for VM or Templates class" do
      before do
        @klass = VmOrTemplate
      end

      it "with one Instance" do
        record_ids = [ @record_1.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Instance"
      end

      it "with multiple Instances" do
        record_ids = [ @record_1.id, @record_2.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Instances"
      end

      it "with one Instance and one Image" do
        record_ids = [ @record_1.id, @record_3.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Image and Instance"
      end

      it "with one Instance and multiple Images" do
        record_ids = [ @record_1.id, @record_3.id, @record_4.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Images and Instance"
      end

      it "with multiple Instances and multiple Images" do
        record_ids = [ @record_1.id, @record_2.id, @record_3.id, @record_4.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Images and Instances"
      end

      it "with multiple Instances and one Virtual Machine" do
        record_ids = [ @record_1.id, @record_2.id, @record_5.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Instances and Virtual Machine"
      end

      it "with multiple Instances and multiple Virtual Machines" do
        record_ids = [ @record_1.id, @record_2.id, @record_5.id, @record_6.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Instances and Virtual Machines"
      end

      it "with multiple Instances, one Image and multiple Virtual Machines" do
        record_ids = [ @record_5.id, @record_6.id, @record_1.id, @record_2.id, @record_4.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Image, Instances, and Virtual Machines"
      end

      it "with multiple Instances, multiple Images and multiple Virtual Machines" do
        record_ids = [ @record_5.id, @record_6.id, @record_1.id, @record_2.id, @record_3.id, @record_4.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Images, Instances, and Virtual Machines"
      end
    end

    context "when formatting flash message for Non VM or Templates class" do
      before do
        @klass = Service
      end

      it "with one Service" do
        record_ids = [ @record_1.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Service"
      end

      it "with multiple Services" do
        record_ids = [ @record_1.id, @record_2.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Services"
      end
    end

  end

  describe "#url_for_record" do
    subject { url_for_record(@record, @action = "show") }

    it "when record is VmOrTemplate" do
      @record = Vm.new
      subject.should == url_for_db(controller_for_vm(model_for_vm(@record)), @action)
    end

    it "when record is not VmOrTemplate" do
      @record = FactoryGirl.create(:host)
      subject.should == url_for_db(@record.class.base_class.to_s, @action)
    end
  end

  describe "custom_buttons" do
    before(:each) do
      @miq_user_role = FactoryGirl.create(:miq_user_role, :name => "EvmRole-super_administrator")
      @miq_group     = FactoryGirl.create(:miq_group, :miq_user_role => @miq_user_role)
      @user          = FactoryGirl.create(:user, :name => 'wilma', :miq_groups => [@miq_group])
    end

    context "when record is VM" do
      before(:each) do
        @record = FactoryGirl.create(:vm_vmware)
      end

      context "and it has no custom buttons" do
        it "#get_custom_buttons" do
          get_custom_buttons(@record).should == []
        end

        it "#custom_buttons_hash" do
          custom_buttons_hash(@record).should == []
        end

        it "#build_custom_buttons_toolbar" do
          build_custom_buttons_toolbar(@record).should == {:button_groups=>[]}
        end

        it "#record_to_service_buttons" do
          record_to_service_buttons(@record).should == []
        end
      end

      context "and it has custom buttons" do
        before(:each) do
          @set_data = { :applies_to_class => 'Vm' }
          @button_set = FactoryGirl.create(:custom_button_set, :set_data => @set_data)
          CustomButton.stub(:get_user).and_return(@user)
          @button1 = FactoryGirl.create(:custom_button, :applies_to_class => 'Vm', :visibility => { :roles => ["_ALL_"]}, :options => {})
          @button_set.add_member @button1
          @button_set.save!
          @button1.save!
        end

        it "#get_custom_buttons" do
          expected_button1 = {
                                :id            => @button1.id,
                                :class         => @button1.applies_to_class,
                                :name          => @button1.name,
                                :description   => @button1.description,
                                :image         => @button1.options[:button_image],
                                :text_display  => @button1.options.has_key?(:display) ? @button1.options[:display] : true,
                                :target_object => @record.id
                             }
          expected_button_set = {
                                  :id           => @button_set.id,
                                  :text         => @button_set.name,
                                  :description  => @button_set.description,
                                  :image        => @button_set.set_data[:button_image],
                                  :text_display => @button_set.set_data.has_key?(:display) ? @button_set.set_data[:display] : true,
                                  :buttons      => [expected_button1]
                                }

          get_custom_buttons(@record).should == [expected_button_set]
        end

        it "#record_to_service_buttons" do
          record_to_service_buttons(@record).should == []
        end

        it "#custom_buttons_hash" do
          escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
          button1 = {
                      :button     => "custom__custom_#{@button1.id}",
                      :image      => "custom-#{@button1.options[:button_image]}",
                      :title      => CGI.escapeHTML(@button1.description.to_s),
                      :text       => escaped_button1_text,
                      :enabled    => "true",
                      :url        => "button",
                      :url_parms  => "?id=#{@record.id}&button_id=#{@button1.id}&cls=#{@record.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
                    }
          button_set_item1_items = [button1]
          button_set_item1 = {
                    :buttonSelect => "custom_#{@button_set.id}",
                    :image        => "custom-#{@button_set.set_data[:button_image]}",
                    :title        => @button_set.description,
                    :text         => @button_set.name,
                    :enabled      => "true",
                    :items        => button_set_item1_items
                  }
          items = [ button_set_item1 ]
          name = "custom_buttons_#{@button_set.name}"
          custom_buttons_hash(@record).should == [ :name => name, :items => items ]
        end

        it "#build_custom_buttons_toolbar" do
          escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
          button1 = {
                      :button     => "custom__custom_#{@button1.id}",
                      :image      => "custom-#{@button1.options[:button_image]}",
                      :title      => CGI.escapeHTML(@button1.description.to_s),
                      :text       => escaped_button1_text,
                      :enabled    => "true",
                      :url        => "button",
                      :url_parms  => "?id=#{@record.id}&button_id=#{@button1.id}&cls=#{@record.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
                    }
          button_set_item1_items = [button1]
          button_set_item1 = {
                    :buttonSelect => "custom_#{@button_set.id}",
                    :image        => "custom-#{@button_set.set_data[:button_image]}",
                    :title        => @button_set.description,
                    :text         => @button_set.name,
                    :enabled      => "true",
                    :items        => button_set_item1_items
                  }
          button_set1_header = {
                                 :name  => "custom_buttons_#{@button_set.name}",
                                 :items => [button_set_item1]
                               }
          button_groups = [button_set1_header]
          build_custom_buttons_toolbar(@record).should == { :button_groups => button_groups }
        end
      end
    end

    context "when record is Service" do
      before(:each) do
        @service_template = FactoryGirl.create(:service_template)
        @record = FactoryGirl.create(:service, :service_template => @service_template)
      end

      context "and it has no custom buttons" do
        it "#get_custom_buttons" do
          get_custom_buttons(@record).should == []
        end

        it "#custom_buttons_hash" do
          custom_buttons_hash(@record).should == []
        end

        it "#build_custom_buttons_toolbar" do
          build_custom_buttons_toolbar(@record).should == {:button_groups=>[]}
        end

        it "#record_to_service_buttons" do
          record_to_service_buttons(@record).should == []
        end
      end

      context "and it has custom buttons" do
        before(:each) do
          @set_data = { :applies_to_class => 'ServiceTemplate' , :applies_to_id => @service_template.id}
          @button_set = FactoryGirl.create(:custom_button_set, :set_data => @set_data)
          CustomButton.stub(:get_user).and_return(@user)
          @button1 = FactoryGirl.create(:custom_button, :applies_to_class => 'ServiceTemplate', :visibility => { :roles => ["_ALL_"]}, :options => {})
          @button_set.add_member @button1
          @button_set.save!
          @button1.save!
        end

        it "#custom_buttons_hash" do
          escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
          button1 = {
                      :button     => "custom__custom_#{@button1.id}",
                      :image      => "custom-#{@button1.options[:button_image]}",
                      :title      => CGI.escapeHTML(@button1.description.to_s),
                      :text       => escaped_button1_text,
                      :enabled    => "true",
                      :url        => "button",
                      :url_parms  => "?id=#{@record.id}&button_id=#{@button1.id}&cls=#{@record.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
                    }
          button_set_item1_items = [button1]
          button_set_item1 = {
                    :buttonSelect => "custom_#{@button_set.id}",
                    :image        => "custom-#{@button_set.set_data[:button_image]}",
                    :title        => @button_set.description,
                    :text         => @button_set.name,
                    :enabled      => "true",
                    :items        => button_set_item1_items
                  }
          items = [ button_set_item1 ]
          name = "custom_buttons_#{@button_set.name}"
          custom_buttons_hash(@record).should == [ :name => name, :items => items ]
        end

        it "#build_custom_buttons_toolbar" do
          escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
          button1 = {
                      :button     => "custom__custom_#{@button1.id}",
                      :image      => "custom-#{@button1.options[:button_image]}",
                      :title      => CGI.escapeHTML(@button1.description.to_s),
                      :text       => escaped_button1_text,
                      :enabled    => "true",
                      :url        => "button",
                      :url_parms  => "?id=#{@record.id}&button_id=#{@button1.id}&cls=#{@record.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
                    }
          button_set_item1_items = [button1]
          button_set_item1 = {
                    :buttonSelect => "custom_#{@button_set.id}",
                    :image        => "custom-#{@button_set.set_data[:button_image]}",
                    :title        => @button_set.description,
                    :text         => @button_set.name,
                    :enabled      => "true",
                    :items        => button_set_item1_items
                  }
          button_set1_header = {
                                 :name  => "custom_buttons_#{@button_set.name}",
                                 :items => [button_set_item1]
                               }
          button_groups = [button_set1_header]
          build_custom_buttons_toolbar(@record).should == { :button_groups => button_groups }

          @button2 = FactoryGirl.create(:custom_button, :applies_to_class => 'ServiceTemplate', :applies_to_id => @service_template.id, :visibility => { :roles => ["_ALL_"]}, :options => {})

          escaped_button2_text = CGI.escapeHTML(@button2.name.to_s)
          expected_button2 = {
                      :button     => "custom__custom_#{@button2.id}",
                      :image      => "custom-#{@button2.options[:button_image]}",
                      :title      => CGI.escapeHTML(@button2.description.to_s),
                      :text       => escaped_button2_text,
                      :enabled    => nil,
                      :url        => "button",
                      :url_parms  => "?id=#{@record.id}&button_id=#{@button2.id}&cls=#{@record.class.name}&pressed=custom_button&desc=#{escaped_button2_text}"
                    }
          button_set2_header = {
                                 :name  => "custom_buttons_",
                                 :items => [expected_button2]
                               }
          button_groups = [button_set1_header, button_set2_header]
          build_custom_buttons_toolbar(@record).should == { :button_groups => button_groups }
        end

        it "#get_custom_buttons" do
          expected_button1 = {
                                :id            => @button1.id,
                                :class         => @button1.applies_to_class,
                                :name          => @button1.name,
                                :description   => @button1.description,
                                :image         => @button1.options[:button_image],
                                :text_display  => @button1.options.has_key?(:display) ? @button1.options[:display] : true,
                                :target_object => @record.id
                             }
          expected_buttons = [expected_button1]
          expected_button_set = {
                                  :id           => @button_set.id,
                                  :text         => @button_set.name,
                                  :description  => @button_set.description,
                                  :image        => @button_set.set_data[:button_image],
                                  :text_display => @button_set.set_data.has_key?(:display) ? @button_set.set_data[:display] : true,
                                  :buttons      => [expected_button1]
                                }

          get_custom_buttons(@record).should == [expected_button_set]

          button2 = FactoryGirl.create(:custom_button, :applies_to_class => 'ServiceTemplate', :applies_to_id => @service_template.id, :visibility => { :roles => ["_ALL_"]}, :options => {})

          get_custom_buttons(@record).should == [expected_button_set]
        end
      end

      it "#record_to_service_buttons" do
        record_to_service_buttons(@record).should == []
        button2 = FactoryGirl.create(:custom_button, :applies_to_class => 'ServiceTemplate', :applies_to_id => @service_template.id, :visibility => { :roles => ["_ALL_"]}, :options => {})
        expected_button2 = {
                              :id            => button2.id,
                              :class         => button2.applies_to_class,
                              :name          => button2.name,
                              :description   => button2.description,
                              :image         => button2.options[:button_image],
                              :text_display  => button2.options.has_key?(:display) ? button2.options[:display] : true,
                              :target_object => @record.id
                           }
        record_to_service_buttons(@record).should == [expected_button2]
      end

    end
  end

  describe "#url_for_db" do
    before do
      @action = 'show'
      @id = 12
    end

    context "when with @vm" do
      before do
        @vm = FactoryGirl.create(:vm_vmware)
      end

      ["Account", "User", "Group", "Patch", "GuestApplication"].each do |d|
        it "and db = #{d}" do
          db = d
          @last_action = (d == "Account" ? "users" : d.tableize)
          url_for_db(db, @action).should == url_for(:controller => "vm_or_template",
                                                    :action     => @lastaction,
                                                    :id         => @vm,
                                                    :show       => @id)
        end
      end

      it "otherwise" do
        db = "vm"
        c, a = db_to_controller(db, @action)
        url_for_db(db, @action).should == url_for(:controller=>c, :action=>a, :id=>@id)
      end
    end

    context "when with @host" do
      before do
        @host = FactoryGirl.create(:host)
        @lastaction = "list"
      end

       ["Patch", "GuestApplication"].each do |d|
         it "and db = #{d}" do
           db = d
           url_for_db(db, @action).should == url_for(:controller=>"host", :action=>@lastaction, :id=>@host, :show=>@id)
         end
       end

       it "otherwise" do
         db = "vm"
         c, a = db_to_controller(db, @action)
         url_for_db(db, @action).should == url_for(:controller=>c, :action=>a, :id=>@id)
      end
    end

    it "when with no @vm, no @host, and no @db" do
      db = 'Vm'
      url_for_db(db, @action).should == "/vm/#{@action}/#{@id}"
    end
  end

  describe "#db_to_controller" do
    subject { db_to_controller(@db) }

    context "when with ActionSet" do
      before { @db = "ActionSet" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "miq_action"
        subject[1].should == "show_set"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "miq_action"
        subject[1].should == "show_set"
      end
    end

    context "when with AutomationRequest" do
      before { @db = "AutomationRequest" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "miq_request"
        subject[1].should == "show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "miq_request"
        subject[1].should == "show"
      end
    end

    context "when with ConditionSet" do
      before do
        @db = "ConditionSet"
      end

      it "and @explorer" do
        @explorer = true
        subject[0].should == "condition"
        subject[1].should == "x_show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "condition"
        subject[1].should == "show"
      end
    end

    context "when with EmsInfra" do
      before { @db = "EmsInfra" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "ems_infra"
        subject[1].should == "x_show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "ems_infra"
        subject[1].should == "show"
      end
    end

    context "when with EmsCloud" do
      before { @db = "EmsCloud" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "ems_cloud"
        subject[1].should == "x_show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "ems_cloud"
        subject[1].should == "show"
      end
    end

    context "when with ScanItemSet" do
      before { @db = "ScanItemSet" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "ops"
        subject[1].should == "ap_show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "ops"
        subject[1].should == "ap_show"
      end
    end

    context "when with MiqEvent" do
      before { @db = "MiqEvent" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "event"
        subject[1].should == "_none_"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "event"
        subject[1].should == "_none_"
      end
    end

    ["User", "Group", "Patch", "GuestApplication"].each do |db|
      context "when with #{db}" do
        before { @db = db ; @lastaction = "some_action"}

        it "and @explorer" do
          @explorer = true
          subject[0].should == "vm"
          subject[1].should == @lastaction
        end

        it "and not @explorer" do
          @explorer = nil
          subject[0].should == "vm"
          subject[1].should == @lastaction
        end
      end
    end

    context "when with MiqReportResult" do
      before { @db = "MiqReportResult" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "report"
        subject[1].should == "show_saved"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "report"
        subject[1].should == "show_saved"
      end
    end

    context "when with MiqAeClass" do
      before { @db = "MiqAeClass" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "miq_ae_class"
        subject[1].should == "show_instances"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "miq_ae_class"
        subject[1].should == "show_instances"
      end
    end

    context "when with MiqAeInstance" do
      before { @db = "MiqAeInstance" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "miq_ae_class"
        subject[1].should == "show_details"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "miq_ae_class"
        subject[1].should == "show_details"
      end
    end

    ["ServiceResource", "ServiceTemplate"].each do |db|
      context "when with #{db}" do
        before { @db = db }

        it "and @explorer" do
          @explorer = true
          subject[0].should == "catalog"
          subject[1].should == "x_show"
        end

        it "and not @explorer" do
          @explorer = nil
          subject[0].should == "catalog"
          subject[1].should == "show"
        end
      end
    end
  end

  describe "#get_image" do
    subject { get_image(@img, @button_name) }

    context "when with show_summary" do
      before do
        @button_name = "show_summary"
        @img = "reload"
      end

      it "and layout is scan_profile" do
        @layout = "scan_profile"
        subject.should == "summary-green"
      end

      it "and layout is miq_schedule" do
        @layout = "miq_schedule"
        subject.should == "summary-green"
      end

      it "and layout is miq_proxy" do
        @layout = "miq_schedule"
        subject.should == "summary-green"
      end

      it "otherwise" do
        @layout = "some_thing"
        subject.should == @img
      end
    end

    it "when not with show_summary" do
      @button_name = "summary_reload"
      @img = "reload"
      subject.should == @img
    end
  end #get_image

  describe "#build_toolbar_hide_button" do
    subject { build_toolbar_hide_button(@id) }
    before do
      @user = FactoryGirl.create(:user, :name => 'Fred Flintstone', :userid => 'fred')
      @record = double("record")
      User.stub(:current_user).and_return(@user)
      @settings = {
        :views => {
          :compare      => 'compressed',
          :drift        => 'compressed',
          :compare_mode => 'exists',
          :drift_mode   => 'exists',
          :treesize     => '32'
        }
      }
    end

    def setup_x_tree_history
      @sb = { :history => { :testing => %w(some thing to test with) },
              :active_tree => :testing }
    end

    %w(
      view_grid
      view_tile
      view_list
      download_text
      download_csv
      download_pdf
      download_view
      vm_download_pdf
      refresh_log
      fetch_log
    ).each do |item|
      it "when with #{item}" do
        @id = item
        subject.should be_false
      end
    end

    it "when with show_summary and not explorer" do
      @id = "show_summary"
      @explorer = false
      subject.should be_false
    end

    it "when with show_summary and explorer" do
      @id = "show_summary"
      @explorer = true
      subject.should be_true
    end

    it "when with history_1" do
      setup_x_tree_history
      @id = "history_1"
      subject.should be_false
    end

    %w(0 1 2 3 4).each do |n|
      it "when with existing history_#{n}" do
        setup_x_tree_history
        @id = "history_#{n}"
        subject.should be_false
      end
    end

    it "when not history_1 and the tree history not exist" do
      setup_x_tree_history
      @id = "history_10"
      subject.should be_true
    end

    it "when id likes old_dialogs_*" do
      @id = "old_dialogs_some_thing"
      subject.should be_true
    end

    it "when id likes ab_*" do
      @id = "ab_some_thing"
      subject.should be_true
    end

    context "when with button_add" do
      before { @id = "button_add" }
      it "and no record_id" do
        @edit = { :rec_id => nil }
        subject.should be_false
      end

      it "and record_id" do
        @edit = { :rec_id => "record id" }
        subject.should be_true
      end
    end

    ["button_save","button_reset"].each do |id|
      context "when with #{id}" do
        before { @id = id }
        it "and record_id" do
          @edit = { :rec_id => "record id" }
          subject.should be_false
        end

        it "and no record_id" do
          @edit = { :rec_id => nil }
          subject.should be_true
        end
      end
    end

    it "when with button_cancel" do
      @id = "button_cancel"
      subject.should be_false
    end

    ["miq_task_", "compare_", "drift_", "comparemode_", "driftmode_", "custom_"].each do |i|
      it "when id likes #{i}*" do
        @id = "#{i}some_thing"
        subject.should be_false
      end
    end

    context "when with miq_request_reload" do
      before { @id = "miq_request_reload" }
      it "and lastaction is show_list" do
        @lastaction = "show_list"
        subject.should be_false
      end

      it "and lastaction is not show_list" do
        @lastaction = "log"
        subject.should be_true
      end
    end

    context "when with miq_request_reload" do
      before { @id = "miq_request_reload" }
      it "and showtype is miq_provisions" do
        @showtype = "miq_provisions"
        subject.should be_false
      end

      it "and showtype is not miq_provisions" do
        @showtype = "compare"
        subject.should be_true
      end
    end

    context "when with miq_request_approve" do
      before { @id = "miq_request_approve" }
      it "and miq_request_approval feature is not allowed" do
        subject.should be_true
      end

      it "and miq_request_approval feature is allowed" do
        @user.stub(:role_allows?).and_return(true)
        subject.should be_false
      end
    end

    context "when with miq_request_deny" do
      before { @id = "miq_request_deny" }
      it "and miq_request_approval feature is not allowed" do
        subject.should be_true
      end

      it "and miq_request_approval feature is allowed" do
        @user.stub(:role_allows?).and_return(true)
        subject.should be_false
      end
    end

    it "when id likes dialog_*" do
      @id = "dialog_some_thing"
      subject.should be_false
    end

    it "when with miq_request_approve and allowed by the role" do
      @id = "miq_request_approve"
      # when the role allows the feature
      @user.stub(:role_allows?).and_return(true)
      subject.should be_false
    end

    it "when with miq_request_deny and allowed by the role" do
      @id = "miq_request_deny"
      # when the role allows the feature
      @user.stub(:role_allows?).and_return(true)
      subject.should be_false
    end

    it "when not with miq_request_approve or miq_request_deny and not allowed by the role" do
      @id = "miq_request_edit"
      subject.should be_true
    end

    ["ems_cluster_protect","ext_management_system_protect",
        "host_analyze_check_compliance","host_check_compliance","host_protect",
        "host_shutdown","host_reboot","host_standby",
        "host_enter_maint_mode", "host_exit_maint_mode",
        "host_start","host_stop","host_reset",
        "repo_protect",
        "resource_pool_protect",
        "vm_check_compliance",
        "vm_guest_startup",
        "vm_guest_shutdown",
        "vm_guest_standby",
        "vm_guest_restart",
        "vm_policy_sim",
        "vm_protect",
        "vm_start",
        "vm_stop",
        "vm_suspend",
        "vm_reset",
        "vm_retire",
        "vm_retire_now",
        "vm_snapshot_add",
        "vm_snapshot_delete",
        "vm_snapshot_delete_all",
        "vm_snapshot_revert"].each do |id|
      it "when with #{id}" do
        @id = id
        @user.stub(:role_allows?).and_return(true)
        subject.should be_false
      end
    end

    context "when with dialog_add_box" do
      before do
        @id = 'dialog_add_box'
        @edit = { :some => 'thing' }
      end

      it "and !@edit" do
        @edit = nil
        subject.should be_true
      end

      it "and nodes < 2" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'root' }},
              :active_tree => :svcs_tree }
        subject.should be_true

        @sb = { :trees => { :svcs_tree => {:active_node => '' }},
              :active_tree => :svcs_tree }
        subject.should be_true
      end

      it "and 2 nodes" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'some_thing' }},
              :active_tree => :svcs_tree }
        subject.should be_false
      end

      it "and 3 nodes" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'something_to_test' }},
              :active_tree => :svcs_tree }
        subject.should be_false
      end

      it "and nodes > 3" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'some_thing_to_test' }},
              :active_tree => :svcs_tree }
        subject.should be_true
      end
    end

    context "when with dialog_add_element" do
      before do
        @id = "dialog_add_element"
        @edit = { :some => 'thing' }
      end

      it "and !@edit" do
        @edit = nil
        subject.should be_true
      end

      it "and nodes < 3" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'some_thing' }},
              :active_tree => :svcs_tree }
        subject.should be_true

        @sb = { :trees => { :svcs_tree => {:active_node => '' }},
              :active_tree => :svcs_tree }
        subject.should be_true
      end

      it "and 3 nodes" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'something_to_test' }},
              :active_tree => :svcs_tree }
        subject.should be_false
      end

      it "and 4 nodes" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'some_thing_to_test' }},
              :active_tree => :svcs_tree }
        subject.should be_false
      end

      it "and nodes > 4" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'some_thing_to_test_with' }},
              :active_tree => :svcs_tree }
        subject.should be_true
      end
    end

    context "when with dialog_add_tab" do
      before do
        @id = "dialog_add_tab"
        @edit = { :some => 'thing' }
      end

      it "and !@edit" do
        @edit = nil
        subject.should be_true
      end

      it "and nodes <= 2" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'some_thing' }},
              :active_tree => :svcs_tree }
        subject.should be_false

        @sb = { :trees => { :svcs_tree => {:active_node => 'something' }},
              :active_tree => :svcs_tree }
        subject.should be_false

        @sb = { :trees => { :svcs_tree => {:active_node => '' }},
              :active_tree => :svcs_tree }
        subject.should be_false
      end

      it "and nodes > 2" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'something_to_test' }},
              :active_tree => :svcs_tree }
        subject.should be_true
      end
    end

    context "when with dialog_res_discard" do
      before do
        @id = "dialog_res_discard"
        @edit = { :some => 'thing' }
      end

      it "and !@edit" do
        @edit = nil
        subject.should be_true
      end

      it "and @sb[:edit_typ] != 'add'" do
        @sb = {:edit_typ => "something"}
        subject.should be_true
      end

      it "and @sb[:edit_typ] = 'add'" do
        # @sb[:trees][@sb[:active_tree]][:active_node] is required to pass the test.
        @sb = { :trees => { :svcs_tree => {:active_node => 'something_to_test' }},
              :active_tree => :svcs_tree,
              :edit_typ => 'add' }

        subject.should be_false
      end
    end

    context "when with dialog_resource_remove" do
      before do
        @id = "dialog_resource_remove"
        @edit = { :some => 'thing' }
        @sb = { :trees => { :svcs_tree => {:active_node => 'something_to_test' }},
              :active_tree => :svcs_tree}
      end

      it "and !@edit" do
        @edit = nil
        subject.should be_true
      end

      it "and @sb[:edit_typ] = 'add'" do
        @sb[:edit_typ] = 'add'
        subject.should be_true
      end

      it "and @sb[:edit_typ] != 'add'" do
        subject.should be_false
      end

      it "and active_node = 'root'" do
        @sb = { :trees => { :svcs_tree => {:active_node => 'root' }},
              :active_tree => :svcs_tree}
        subject.should be_true
      end

      it "and active_node != 'root'" do
        subject.should be_false
      end
    end

    ["dialog_copy","dialog_delete","dialog_edit","dialog_new"].each do |id|
      context "when with #{id}" do
        before do
          @id = id
          @edit = nil
        end

        it "and @edit" do
          @edit = { :rec_id => "record id", :current => {} }
          subject.should be_true
        end

        it "and !@edit" do
          subject.should be_false
        end
      end
    end

    ["host_miq_request_new", "vm_miq_request_new", "vm_clone", "vm_publish", "vm_pre_prov"].each do |id|
      it "when with #{id}" do
        @id = id
        @user.stub(:role_allows?).and_return(true)
        subject.should be_false
      end
    end

    context "when with miq_task_canceljob" do
      before do
        @id = 'miq_task_canceljob'
        @user.stub(:role_allows?).and_return(true)
      end

      it "and @layout != all_tasks" do
        @layout = "x_tasks"
        subject.should == true
      end

      it "and @layout != all_ui_tasks" do
        @layout = "x_ui_tasks"
        subject.should == true
      end

      it "and @layout = all_tasks" do
        @layout = "all_tasks"
        subject.should == false
      end

      it "and @layout = all_ui_tasks" do
        @layout = "all_ui_tasks"
        subject.should == false
      end
    end

    context "when with vm_console" do
      before do
        @id = "vm_console"
        @user.stub(:role_allows?).and_return(true)
        @record.stub(:console_supported? => false)
      end

      it "and record is not console supported" do
        subject.should be_true
      end

      it "and server's remote_console_type not set" do
        @vmdb_config = { :server => nil }
        subject.should be_true
      end

      it "and server's remote_console_type is not MKS" do
        @vmdb_config = { :server => { :remote_console_type => "not_MKS" } }
        subject.should be_true
      end

      it "and record is console supported and server's remote_console_type is MKS" do
        @record.stub(:console_supported? => true)
        @vmdb_config = { :server => { :remote_console_type => "MKS" } }
        subject.should be_false
      end
    end

    context "when with vm_vnc_console" do
      before do
        @id = "vm_vnc_console"
        @user.stub(:role_allows?).and_return(true)
        @record.stub(:console_supported? => false)
      end

      it "and record is not console supported" do
        subject.should == true
      end

      it "and server's remote_console_type not set" do
        @vmdb_config = { :server => nil }
        subject.should == true
      end

      it "and server's remote_console_type is not VNC" do
        @vmdb_config = { :server => { :remote_console_type => "not_VNC" } }
        subject.should == true
      end

      it "and record is console supported and server's remote_console_type is VNC" do
        @record.stub(:console_supported? => true)
        @vmdb_config = { :server => { :remote_console_type => "VNC" } }
        subject.should == false
      end
    end

    context "when with vm_vmrc_console" do
      before do
        @id = "vm_vmrc_console"
        @user.stub(:role_allows?).and_return(true)
        @record.stub(:console_supported? => false)
      end

      it "and record is not console supported" do
        subject.should == true
      end

      it "and server's remote_console_type not set" do
        @vmdb_config = { :server => nil }
        subject.should == true
      end

      it "and server's remote_console_type is not VMRC" do
        @vmdb_config = { :server => { :remote_console_type => "not_VMRC" } }
        subject.should == true
      end

      it "and record is console supported and server's remote_console_type is VMRC" do
        @record.stub(:console_supported? => true)
        @vmdb_config = { :server => { :remote_console_type => "VMRC" } }
        subject.should == false
      end
    end

    ["ontap_storage_system_statistics", "ontap_logical_disk_statistics", "ontap_storage_volume_statistics", "ontap_file_share_statistics"].each do |id|
      context "when with #{id}" do
        before do
          @id = id
          @user.stub(:role_allows?).and_return(true)
        end

        it "and @vmdb_config[:product][:smis] != true " do
          @vmdb_config = { :product => { :smis => false } }
          subject.should == true
        end

        it "and @vmdb_config[:product][:smis] = true " do
          @vmdb_config = { :product => { :smis => true } }
          subject.should == false
        end
      end
    end

    context "when with AssignedServerRole" do
      before do
        @record = AssignedServerRole.new
        @user.stub(:role_allows?).and_return(true)
      end

      it "and id = delete_server" do
        @id = "delete_server"
        subject.should == true
      end

      it "and id != server_delete" do
        @id = "server_add"
        subject.should == false
      end
    end

    context "when with EmsCluster" do
      before do
        @record = EmsCluster.new
        @user.stub(:role_allows?).and_return(true)
      end

      context "and id = common_drift" do
        before do
          @id = 'common_drift'
          @lastaction = 'drift_history'
        end

        it "and lastaction = drift_history" do
          subject.should == false
        end
      end

      it "and id != common_drift" do
        @id = 'ems_cluster_view'
        subject.should == false
      end
    end

    context "when with Host" do
      before do
        @record = Host.new
        @user.stub(:role_allows?).and_return(true)
      end

      context "and id = common_drift" do
        before do
          @id = 'common_drift'
          @lastaction = 'drift_history'
        end

        it "and lastaction = drift_history" do
          subject.should == false
        end
      end

      context "and id = host_protect" do
        before do
          @id = 'host_protect'
          @record.stub(:smart? => false)
        end

        it "and record is not smart" do
          subject.should == true
        end

        it "and record is smart" do
          @record.stub(:smart? => true)
          subject.should == false
        end
      end

      context "and id = host_refresh" do
        before do
          @id = 'host_refresh'
          @record.stub(:is_refreshable? => false)
        end

        it "and record is not refreshable" do
          subject.should == true
        end

        it "and record is refreshable" do
          @record.stub(:is_refreshable? => true)
          subject.should == false
        end
      end

      context "and id = host_scan" do
        before { @id = 'host_scan' }

        it "and record is not scannable" do
          @record.stub(:is_scannable? => false)
          subject.should == true
        end

        it "and record is scannable" do
          @record.stub(:is_scannable? => true)
          subject.should == false
        end
      end

      ["host_shutdown","host_standby","host_reboot","host_enter_maint_mode", "host_exit_maint_mode","host_start","host_stop","host_reset"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @record.stub(:is_available? => false)
          end

          it "and record is not available" do
            subject.should == true
          end

          it "and record is available" do
            @record.stub(:is_available? => true)
            subject.should == false
          end
        end
      end

      ["perf_refresh", "perf_reload", "vm_perf_refresh", "vm_perf_reload"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @perf_options = { :typ => "realtime" }
          end

          it "and @perf_options[:typ] != 'realtime'" do
            @perf_options = { :typ => "Daily" }
            subject.should == true
          end

          it "and @perf_options[:typ] = 'realtime'" do
            subject.should == false
          end
        end
      end
    end

    ["MiqProvisionRequest","MiqHostProvisionRequest", "VmReconfigureRequest","VmMigrateRequest", "AutomationRequest", "ServiceTemplateProvisionRequest"].each do |cls|
      context "when with #{cls}" do
        before do
          @record = cls.constantize.new
          @user.stub(:role_allows?).and_return(true)
        end

        context "and id = miq_request_approve" do
          before do
            @id = "miq_request_approve"
            @record.stub(:resource_type => "something", :approval_state => "xx")
          end

          it "and resource_type = AutomationRequest" do
            @record.stub(:resource_type => "AutomationRequest")
            subject.should == false
          end

          it "and approval_state = approved" do
            @record.stub(:approval_state => "approved")
            subject.should == true
          end

          it "and showtype = miq_provisions" do
            @showtype = "miq_provisions"
            subject.should == true
          end

          it "and approval_state != approved and showtype != miq_provisions" do
            subject.should == false
          end
        end

        context "and id = miq_request_deny" do
          before do
            @id = "miq_request_deny"
            @record.stub(:resource_type => "something", :approval_state => "xx")
          end

          it "and resource_type = AutomationRequest" do
            @record.stub(:resource_type => "AutomationRequest")
            subject.should == false
          end

          it "and approval_state = approved" do
            @record.stub(:approval_state => "approved")
            subject.should == true
          end

          it "and approval_state = denied" do
            @record.stub(:approval_state => "denied")
            subject.should == true
          end

          it "and showtype = miq_provisions" do
            @showtype = "miq_provisions"
            subject.should == true
          end

          it "and approval_state != approved|denied and showtype != miq_provisions" do
            subject.should == false
          end
        end

        context "and id = miq_request_delete" do
          before do
            @id = "miq_request_delete"
            @record.stub(:resource_type => "something", :approval_state => "xx", :requester_name => @user.name)
            User.stub(:find_by_userid).and_return(@user)
          end

          it "and resource_type = AutomationRequest" do
            @record.stub(:resource_type => "AutomationRequest")
            subject.should == false
          end

          it "and requester.name != @record.requester_name" do
            @record.stub(:requester_name => 'admin')
            subject.should == true
          end

          it "and approval_state = approved" do
            @record.stub(:approval_state => "approved")
            subject.should == true
          end

          it "and approval_state = denied" do
            @record.stub(:approval_state => "denied")
            subject.should == true
          end

          it "and requester.name = @record.requester_name & approval_state != approved|denied" do
            subject.should == false
          end
        end

        context "and id = miq_request_edit" do
          before do
            @id = "miq_request_edit"
            @record.stub(:resource_type => "something", :approval_state => "xx", :requester_name => @user.name)
            User.stub(:find_by_userid).and_return(@user)
          end

          it "and resource_type = AutomationRequest" do
            @record.stub(:resource_type => "AutomationRequest")
            subject.should == true
          end

          it "and requester.name != @record.requester_name" do
            @record.stub(:requester_name => 'admin')
            subject.should == true
          end

          it "and approval_state = approved" do
            @record.stub(:approval_state => "approved")
            subject.should == true
          end

          it "and approval_state = denied" do
            @record.stub(:approval_state => "denied")
            subject.should == true
          end

          it "and requester.name = @record.requester_name & approval_state != approved|denied" do
            subject.should == false
          end
        end

        context "and id = miq_request_copy" do
          before do
            @id = "miq_request_copy"
            @record.stub(:resource_type  => "MiqProvisionRequest",
                         :approval_state => "pending_approval",
                         :requester_name => @user.name)
            User.stub(:find_by_userid).and_return(@user)
          end

          it "and resource_type = AutomationRequest" do
            @record.stub(:resource_type => "AutomationRequest")
            subject.should == true
          end

          it "and resource_type != MiqProvisionRequest" do
            @record.stub(:resource_type => "SomeRequest")
            subject.should == true
          end

          it "and requester.name != @record.requester_name & showtype = miq_provisions" do
            @showtype = "miq_provisions"
            @record.stub(:requester_name => 'admin')
            subject.should == true
          end

          it "and approval_state = approved & showtype = miq_provisions" do
            @showtype = "miq_provisions"
            @record.stub(:approval_state => "approved")
            subject.should == true
          end

          it "and approval_state = denied & showtype = miq_provisions" do
            @showtype = "miq_provisions"
            @record.stub(:approval_state => "denied")
            subject.should == true
          end

          it "and resource_type = MiqProvisionRequest & requester.name = @record.requester_name & approval_state != approved|denied" do
            @showtype = "miq_provisions"
            subject.should == false
          end

          it "and resource_type = MiqProvisionRequest & showtype != miq_provisions" do
            @record.stub(:requester_name => 'admin')
            subject.should == false
          end
        end
      end
    end

    context "when with MiqAlert" do
      before do
        @record = MiqAlert.new
        @layout = "miq_policy"
      end

      it "alert_copy don't hide if RBAC allows" do
        @user.stub(:role_allows?).and_return(true)
        @id = "alert_copy"
        subject.should be_false
      end

      it "alert_copy hide if RBAC denies" do
        @user.stub(:role_allows?).and_return(false)
        @id = "alert_copy"
        subject.should be_true
      end
    end

    context "when with MiqServer" do
      before do
        @record = MiqServer.new
        @user.stub(:role_allows?).and_return(true)
      end

      ["role_start","role_suspend","promote_server","demote_server",
        "log_download","refresh_logs","log_collect","log_reload","logdepot_edit","processmanager_restart","refresh_workers"].each do |id|
        it "and id = #{id}" do
          @id = id
          subject.should == true
        end
      end

      it "otherwise" do
        @id = 'xx'
        subject.should == false
      end
    end

    context "when with ScanItemSet" do
      before do
        @record = ScanItemSet.new
        @user.stub(:role_allows?).and_return(true)
      end

      ["scan_delete", "scan_edit"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @record.stub(:read_only => false)
          end

          it "and record read only" do
            @record.stub(:read_only => true)
            subject.should == true
          end

          it "and record not read only" do
            subject.should == false
          end
        end
      end
    end

    context "when with ServerRole" do
      before do
        @record = ServerRole.new
        @user.stub(:role_allows?).and_return(true)
      end

      ["server_delete","role_start","role_suspend","promote_server","demote_server"].each do |id|
        it "and id = #{id}" do
          @id = id
          subject.should == true
        end
      end

      it "otherwise" do
        @id = 'xx'
        subject.should == false
      end
    end

    context "when with Vm" do
      before do
        @record = Vm.new
        @user.stub(:role_allows?).and_return(true)
      end

      %w(vm_migrate vm_publish vm_reconfigure).each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and vendor is redhat" do
            @record.stub(:vendor => "Redhat")
            @record.stub(:type   => "VmRedhat")
            subject.should == true
          end

          it "and vendor is not redhat" do
            @record.stub(:vendor => "Vmware")
            subject.should == false
          end
        end
      end

      context "and id = vm_clone" do
        before { @id = "vm_clone" }

        it "record is not cloneable" do
          @record = Vm.create(:type => "VmMicrosoft", :name => "vm", :location => "l2", :vendor => "microsoft")
          subject.should == true
        end

        it "record is cloneable" do
          @record = Vm.create(:type => "VmRedhat", :name => "rh", :location => "l1", :vendor => "redhat")
          subject.should == false
        end
      end

      context "and id = vm_collect_running_processes" do
        before do
          @id = "vm_collect_running_processes"
          @record.stub(:retired => false, :current_state => "new")
          @record.stub(:is_available?).with(:collect_running_processes).and_return(true)
        end

        it "and @record.retired & !@record.is_available?(:collect_running_processes)" do
          @record.stub(:retired => true)
          @record.stub(:is_available?).with(:collect_running_processes).and_return(false)
          subject.should == true
        end

        it "and @record.current_state = never & !@record.is_available?(:collect_running_processes)" do
          @record.stub(:is_available?).with(:collect_running_processes).and_return(false)
          @record.stub(:current_state => "never")
          subject.should == true
        end

        it "and @record.is_available?(:collect_running_processes)" do
          subject.should == false
        end

        it "and !@record.retired & @record.current_state != never" do
          subject.should == false
        end
      end

      context "and id = common_drift" do
        before do
          @id = "common_drift"
          @lastaction = "drift"
        end

        it "and @lastaction = drift_history" do
          @lastaction = "drift_history"
          subject.should == false
        end
      end

      ["vm_guest_startup", "vm_start"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @record.stub(:is_available?).with(:start).and_return(true)
          end

          it "and !@record.is_available?(:start)" do
            @record.stub(:is_available?).with(:start).and_return(false)
            subject.should == true
          end

          it "and @record.is_available?(:start)" do
            subject.should == false
          end
        end
      end

      context "and id = vm_guest_standby" do
        before do
          @id = "vm_guest_standby"
          @record.stub(:is_available?).with(:standby_guest).and_return(true)
        end

        it "and !@record.is_available?(:standby_guest)" do
          @record.stub(:is_available?).with(:standby_guest).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:standby_guest)" do
          subject.should == false
        end
      end

      context "and id = vm_guest_shutdown" do
        before do
          @id = "vm_guest_shutdown"
          @record.stub(:is_available?).with(:shutdown_guest).and_return(true)
        end

        it "and !@record.is_available?(:shutdown_guest)" do
          @record.stub(:is_available?).with(:shutdown_guest).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:shutdown_guest)" do
          subject.should == false
        end
      end

      context "and id = vm_guest_restart" do
        before do
          @id = "vm_guest_restart"
          @record.stub(:is_available?).with(:reboot_guest).and_return(true)
        end

        it "and !@record.is_available?(:reboot_guest)" do
          @record.stub(:is_available?).with(:reboot_guest).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:reboot_guest)" do
          subject.should == false
        end
      end

      context "and id = vm_stop" do
        before do
          @id = "vm_stop"
          @record.stub(:is_available?).with(:stop).and_return(true)
        end

        it "and !@record.is_available?(:stop)" do
          @record.stub(:is_available?).with(:stop).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:stop)" do
          subject.should == false
        end
      end

      context "and id = vm_reset" do
        before do
          @id = "vm_reset"
          @record.stub(:is_available?).with(:reset).and_return(true)
        end

        it "and !@record.is_available?(:reset)" do
          @record.stub(:is_available?).with(:reset).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:reset)" do
          subject.should == false
        end
      end

      context "and id = vm_suspend" do
        before do
          @id = "vm_suspend"
          @record.stub(:is_available?).with(:suspend).and_return(true)
        end

        it "and !@record.is_available?(:suspend)" do
          @record.stub(:is_available?).with(:suspend).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:suspend)" do
          subject.should == false
        end
      end

      ["vm_policy_sim","vm_protect"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @record.stub(:host => double(:vmm_product => "Server"))
          end

          it "and @record.host.vmm_product = workstation" do
            @record.stub(:host => double(:vmm_product => "Workstation"))
            subject.should == true
          end

          it "and @record.host.vmm_product != workstation" do
            subject.should == false
          end

          it "and @record.host does exist" do
            @record.stub(:host => nil)
            subject.should == false
          end
        end
      end

      context "and id = vm_refresh" do
        before do
          @id = "vm_refresh"
          @record.stub(:host => double(:vmm_product => "Workstation"), :ext_management_system => true)
        end

        it "and !@record.ext_management_system & @record.host.vmm_product.downcase != workstation" do
          @record.stub(:host => double(:vmm_product => "Server"), :ext_management_system => false)
          subject.should == true
        end

        it "and @record.ext_management_system" do
          subject.should == false
        end

        it "and @record.host.vmm_product.downcase = workstation" do
          subject.should == false
        end
      end

      context "and id = vm_scan" do
        before do
          @id = "vm_scan"
          @record.stub(:has_proxy?).and_return(true)
        end

        it "and !@record.has_proxy?" do
          @record.stub(:has_proxy?).and_return(false)
          subject.should == true
        end

        it "and @record.has_proxy?" do
          subject.should == false
        end
      end

      ["perf_refresh", "perf_reload", "vm_perf_refresh", "vm_perf_reload"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @perf_options = { :typ => "realtime" }
          end

          it "and @perf_options[:typ] != realtime" do
            @perf_options = { :typ => "Daily" }
            subject.should == true
          end

          it "and @perf_options[:typ] = realtime" do
            subject.should == false
          end
        end
      end
    end # with Vm

    context "when with MiqTemplate" do
      before do
        @record = MiqTemplate.new
        @user.stub(:role_allows?).and_return(true)
      end

      context "and id = miq_template_clone" do
        before do
          @id = "miq_template_clone"
        end

        it "record is not cloneable" do
          @record =  MiqTemplate.create(:type     => "TemplateRedhat",
                                        :name     => "rh",
                                        :location => "loc1",
                                        :vendor   => "redhat")
          subject.should == true
        end

        it "record is cloneable" do
          @record =  MiqTemplate.create(:type     => "TemplateVmware",
                                        :name     => "vm",
                                        :location => "loc2",
                                        :vendor   => "vmware")
          subject.should == false
        end
      end

      ["miq_template_policy_sim","miq_template_protect"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @record.stub(:host => double(:vmm_product => "Server"))
          end

          it "and @record.host.vmm_product = workstation" do
            @record.stub(:host => double(:vmm_product => "Workstation"))
            subject.should == true
          end

          it "and !@record.host" do
            @record.stub(:host => nil)
            subject.should == false
          end

          it "and @record.host.vmm_product != workstation" do
            subject.should == false
          end
        end
      end

      context "and id = miq_template_refresh" do
        before do
          @id = "miq_template_refresh"
          @record.stub(:host => double(:vmm_product => "Workstation"), :ext_management_system => true)
        end

        it "and !@record.ext_management_system & @record.host.vmm_product != workstation" do
          @record.stub(:host => double(:vmm_product => "Server"), :ext_management_system => false)
          subject.should == true
        end

        it "and @record.ext_management_system" do
          subject.should == false
        end

        it "and @record.host.vmm_product = workstation" do
          subject.should == false
        end
      end

      context "and id = miq_template_scan" do
        before { @id = "miq_template_scan" }

        it "and !@record.has_proxy?" do
          subject.should == true
        end

        it "and @record.has_proxy?" do
          @record.stub(:has_proxy? => true)
          subject.should == false
        end
      end

      context "and id = miq_template_reload" do
        before { @id = "miq_template_reload" }

        it "and @perf_options[:typ] != realtime" do
          @perf_options = { :typ => "Daily" }
          subject.should == true
        end

        it "and @perf_options[:typ] = realtime" do
          @perf_options = { :typ => "realtime" }
          subject.should == false
        end
      end
    end #MiqTemplate

    context "when with record = nil" do
      before do
        @record = nil
        @user.stub(:role_allows?).and_return(true)
      end

      ["log_download", "log_reload"].each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and @lastaction = workers" do
            @lastaction = "workers"
            subject.should == true
          end

          it "and @lastaction = download_logs" do
            @lastaction = "download_logs"
            subject.should == true
          end

          it "otherwise" do
            subject.should == false
          end
        end
      end

      ["log_collect", "logdepot_edit", "refresh_logs"].each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and @lastaction = workers" do
            @lastaction = "workers"
            subject.should == true
          end

          it "and @lastaction = evm_logs" do
            @lastaction = "evm_logs"
            subject.should == true
          end

          it "and @lastaction = audit_logs" do
            @lastaction = "audit_logs"
            subject.should == true
          end

          it "otherwise" do
            subject.should == false
          end
        end
      end

      ["processmanager_restart", "refresh_workers"].each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and @lastaction = download_logs" do
            @lastaction = "download_logs"
            subject.should == true
          end

          it "and @lastaction = evm_logs" do
            @lastaction = "evm_logs"
            subject.should == true
          end

          it "and @lastaction = audit_logs" do
            @lastaction = "audit_logs"
            subject.should == true
          end

          it "otherwise" do
            subject.should == false
          end
        end
      end

      ["usage_txt", "usage_csv", "usage_pdf", "usage_reportonly"].each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and !@usage_options[:report]" do
            @usage_options = { :some => 'thing' }
            subject.should == true
          end

          it "and @usage_options[:report].table.data is empty" do
            table = double(:data => '')
            @usage_options = { :report => double(:table => table) }
            subject.should == true
          end

          it "and @usage_options[:report].table.data not empty" do
            table = double(:data => 'something interesting')
            @usage_options = { :report => double(:table => table) }
            subject.should == false
          end
        end
      end

      ["timeline_csv", "timeline_pdf", "timeline_txt"].each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and !@report" do
            subject.should == true
          end

          it "and @report" do
            @report = ''
            subject.should == false
          end
        end
      end
    end

    context "when id = ems_infra_scale" do
      before do
        @id = "ems_infra_scale"
      end

      context "when @record = EmsOpenstackInfra" do
        before do
          @record = FactoryGirl.create(:ems_openstack_infra_with_stack)
        end

        it "user allowed" do
          @user.stub(:role_allows?).and_return(true)
          subject.should == false
        end

        it "user not allowed" do
          @user.stub(:role_allows?).and_return(false)
          subject.should == true
        end

        it "button hidden if provider has no stacks" do
          @record = FactoryGirl.create(:ems_openstack_infra)
          @user.stub(:role_allows?).and_return(true)
          subject.should == true
        end

      end

      context "when @record != EmsOpenstackInfra" do
        before do
          @record = EmsVmware.new
        end

        it "user allowed but hide button because wrong provider" do
          @user.stub(:role_allows?).and_return(true)
          subject.should == true
        end

        it "user not allowed" do
          @user.stub(:role_allows?).and_return(false)
          subject.should == true
        end
      end
    end
  end # end of build_toolbar_hide_button

  describe "#build_toolbar_disable_button" do
    subject { build_toolbar_disable_button(@id) }
    before do
      @gtl_type = 'list'
      @settings = {
        :views => {
          :compare      => 'compressed',
          :drift        => 'compressed',
          :compare_mode => 'exists',
          :drift_mode   => 'exists',
          :treesize     => '32'
        }
      }
    end

    def setup_firefox_with_linux
      # setup for mocking is_browser? and is_browser_os?
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('firefox')
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :os).and_return('linux')
    end

    ['list', 'tile', 'grid'].each do |g|
      it "when with view_#{g}" do
        @gtl_type = g
        build_toolbar_disable_button("view_#{g}").should be_true
      end
    end

    it "when with 'history_1' and x_tree_history.length < 2" do
        # setup for x_tree_history
        @sb = { :history => { :testing => %w(something) },
                :active_tree => :testing }
        build_toolbar_disable_button('history_1').should be_true
    end

    ['button_add', 'button_save', 'button_reset'].each do |b|
      it "when with #{b} and not changed" do
        @changed = false
        build_toolbar_disable_button(b).should be_true
      end
    end

    context "when record class = AssignedServerRole" do
      before(:each) { @record = AssignedServerRole.new }

      before do
        @sb = { :active_tree => :diagnostics_tree,
                :trees => { :diagnostics_tree => { :tree => :diagnostics_tree }}}
        @server_role = ServerRole.new(:description=>"some description")
      end

      context "and id = role_start" do
        before :each do
          @message = "This Role is already active on this Server"
          @id = "role_start"

          @record.stub(:miq_server => double(:started? => true), :active => true, :server_role=>@server_role )
        end

        it "when miq server not started" do
          @record.stub(:miq_server => double(:started? => false))
          subject.should == @message
        end

        it "when miq server started but not active" do
          @record.stub(:active => false)
          @record.stub(:miq_server => double(:started? => false))
          subject.should == "Only available Roles on active Servers can be started"
        end

        it_behaves_like 'default true_case'
      end

      context "and id = role_suspend" do
        before(:each) do
          @id = "role_suspend"
          @miq_server = MiqServer.new(:name => "xx miq server", :id => "xx server id")
          @miq_server.stub(:started? => true)
          @record.stub(:miq_server => @miq_server, :active => true,
                          :server_role => @server_role)
          @server_role.max_concurrent = 1
        end

        context "when miq server started and active" do
          it "and server_role.max_concurrent == 1" do
            @record.stub(:miq_server => @miq_server)
            subject.should == "Activate the #{@record.server_role.description} Role on another Server to suspend it on #{@record.miq_server.name} [#{@record.miq_server.id}]"
          end
          it_behaves_like 'default true_case'
        end

        it "when miq_server not started or not active" do
          @record.stub(:miq_server => double(:started? => false), :active => false)
          subject.should == "Only active Roles on active Servers can be suspended"
        end
      end
    end

    context "when record class = OntapStorageSystem" do
      before do
        @record = OntapStorageSystem.new
        @record.stub(:latest_derived_metrics => true)
      end

      context "and id = ontap_storage_system_statistics" do
        before(:each) { @id = "ontap_storage_system_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = OntapLogicalDisk" do
      before { @record = OntapLogicalDisk.new }

      context "and id = ontap_logical_disk_perf" do
        before do
          @id = "ontap_logical_disk_perf"
          @record.stub(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Logical Disk"
        it_behaves_like 'default case'
      end

      context "and id = ontap_logical_disk_statistics" do
        before do
          @id = "ontap_logical_disk_statistics"
          @record.stub(:latest_derived_metrics => true)
        end
        it_behaves_like 'record without latest derived metrics', "No Statistics collected for this Logical Disk"
        it_behaves_like 'default case'
      end
    end

    context "when record class = CimBaseStorageExtent" do
      before do
        @record = CimBaseStorageExtent.new
        @record.stub(:latest_derived_metrics => true)
      end

      context "and id = cim_base_storage_extent_statistics" do
        before { @id = "cim_base_storage_extent_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = OntapStorageVolume" do
      before do
        @record = OntapStorageVolume.new
        @record.stub(:latest_derived_metrics => true)
      end

      context "and id = ontap_storage_volume_statistics" do
        before { @id = "ontap_storage_volume_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = OntapFileShare" do
      before do
        @record = OntapFileShare.new
        @record.stub(:latest_derived_metrics => true)
      end
      context "and id = ontap_file_share_statistics" do
        before { @id = "ontap_file_share_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = SniaLocalFileSystem" do
      before do
        @record = SniaLocalFileSystem.new
        @record.stub(:latest_derived_metrics => true)
      end
      context "and id = snia_local_file_system_statistics" do
        before { @id = "snia_local_file_system_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = EmsCluster" do
      before do
        @record = EmsCluster.new
        @record.stub(:has_perf_data? => true, :has_events? => true)
      end

      context "and id = ems_cluster_perf" do
        before { @id = "ems_cluster_perf" }
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Cluster"
        it_behaves_like 'default case'
      end

      context "and id = ems_cluster_timeline" do
        before { @id = "ems_cluster_timeline" }
        it_behaves_like 'record without ems events and policy events', "No Timeline data has been collected for this Cluster"
        it_behaves_like 'default case'
      end
    end

    context "when record class = Host" do
      before do
        @record = Host.new
        @record.stub(:has_perf_data? => true)
      end

      context "and id = host_perf" do
        before { @id = "host_perf" }
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Host"
        it_behaves_like 'default case'
      end

      context "and id = host_miq_request_new" do
        before do
          @id = "host_miq_request_new"
          @record.stub(:mac_address).and_return("00:0D:93:13:51:1A")
          PxeServer.stub(:all).and_return(['p1','p2'])
        end
        it "when without mac address" do
          @record.stub(:mac_address).and_return(false)
          subject.should == "This Host can not be provisioned because the MAC address is not known"
        end

        it "when no PXE servers" do
          PxeServer.stub(:all).and_return([])
          subject.should == "No PXE Servers are available for Host provisioning"
        end

        it_behaves_like 'default case'
      end

      context "and id = host_refresh" do
        before do
          @id = "host_refresh"
          @record.stub(:is_refreshable_now? => true)
        end
        it "when not configured for refresh" do
          message = "Host not configured for refresh"
          @record.stub(:is_refreshable_now_error_message => message, :is_refreshable_now? => false)
          subject.should == message
        end

        it_behaves_like 'default case'
      end

      context "and id = host_scan" do
        before do
          @id = "host_scan"
          @record.stub(:is_scannable_now? => true)
        end

        it "when not scannable now" do
          message = "Provide credentials for IPMI"
          @record.stub(:is_scannable_now? => false, :is_scannable_now_error_message => message)
          subject.should == message
        end

        it_behaves_like 'default case'
      end

      context "and id = host_timeline" do
        before do
          @id = "host_timeline"
          @record.stub(:has_events?).and_return(true)
        end

        it_behaves_like 'record without ems events and policy events', "No Timeline data has been collected for this Host"
        it_behaves_like 'default case'
      end

      context "and id = host_shutdown" do
        before do
          @id = "host_shutdown"
          @record.stub(:is_available_now_error_message => false)
        end
        it_behaves_like 'record with error message', 'shutdown'
        it_behaves_like 'default case'
      end

      context "and id = host_restart" do
        before do
          @id = "host_restart"
          @record.stub(:is_available_now_error_message => false)
        end

        it_behaves_like 'record with error message', 'reboot'
        it_behaves_like 'default case'
      end
    end

    context "when record class = MiqServer" do
      context "and id = delete_server" do
        before do
          @record = MiqServer.new('name' => 'Server1', 'id' => 'Server ID')
          @id = "delete_server"
        end
        it "is deleteable?" do
          @record.stub(:is_deleteable?).and_return(false)
          subject.should include('Server ')
          subject.should include('can only be deleted if it is stopped or has not responded for a while')
        end
        it_behaves_like 'default case'
      end
    end

    context "when record class = MiqWidget" do
      context "and id = widget_generate_content" do
        before do
          @id = "widget_generate_content"
          @record = FactoryGirl.create(:miq_widget)
        end
        it "when not member of a widgetset" do
          subject.should == "Widget has to be assigned to a dashboard to generate content"
        end

        it "when Widget content generation is already running or queued up" do
          @temp = Hash.new
          @temp[:widget_running] = true
          db = FactoryGirl.create(:miq_widget_set)
          db.replace_children([@record])
          subject.should == "This Widget content generation is already running or queued up"
        end
      end
    end

    context "when record class = ServiceTemplate" do
      context "and id = svc_catalog_provision" do
        before do
          @record = ServiceTemplate.new
          @id = "svc_catalog_provision"
        end

        it "no provision dialog is available when action = 'provision'" do
          @record.stub(:resource_actions).and_return([])
          subject.should == "No Ordering Dialog is available"
        end

        it "when a provision dialog is available" do
          @record.stub(:resource_actions => [ double(:action => 'Provision', :dialog_id => '10')] )
          Dialog.stub(:find_by_id => 'some thing')
          subject.should be_false
        end
      end
    end

    context "when record class = Storage" do
      before { @record = Storage.new }

      context "and id = storage_perf" do
        before do
          @id = "storage_perf"
          @record.stub(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Datastore"
        it_behaves_like 'default case'
      end

      context "and id = storage_delete" do
        before { @id = "storage_delete" }
        it "when with VMs or Hosts" do
          @record.stub(:hosts).and_return(['h1', 'h2'])
          subject.should == "Only Datastore without VMs and Hosts can be removed"

          @record.stub(:hosts => [], :vms_and_templates => ['v1'])
          subject.should == "Only Datastore without VMs and Hosts can be removed"
        end
        it_behaves_like 'default case'
      end
    end

    context "when record class = Vm" do
      before { @record = Vm.new }

      context "and id = vm_perf" do
        before do
          @id = "vm_perf"
          @record.stub(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this VM"
        it_behaves_like 'default case'
      end

      context "id = vm_collect_running_processes" do
        before do
          @id = "vm_collect_running_processes"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'collect_running_processes'
        it_behaves_like 'default case'
      end

      context "and id = vm_console" do
        before do
          @id = "vm_console"
          @record.stub(:current_state => 'on')
          setup_firefox_with_linux
        end

        it_behaves_like 'vm not powered on', "The web-based console is not available because the VM is not powered on"
        it_behaves_like 'default case'
      end

      context "and id = vm_vnc_console" do
        before do
          @id = "vm_vnc_console"
          @record.stub(:current_state => 'on', :ipaddresses => '192.168.1.1')
        end

        it_behaves_like 'vm not powered on', "The web-based VNC console is not available because the VM is not powered on"
        it_behaves_like 'default case'
      end

      context "and id = vm_vmrc_console" do
        before do
          @id = "vm_vmrc_console"
          @record.stub(:current_state => 'on', :validate_remote_console_vmrc_support => true)
          setup_firefox_with_linux
        end

        it "raise MiqException::RemoteConsoleNotSupportedError when can't get remote console url" do
          @record.unstub(:validate_remote_console_vmrc_support)
          subject.should include("VM VMRC Console error")
          subject.should include("VMRC remote console is not supported on")
        end

        it_behaves_like 'vm not powered on', "The web-based console is not available because the VM is not powered on"
      end

      context "and id = vm_guest_startup" do
        before do
          @id = "vm_guest_startup"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'start'
        it_behaves_like 'default case'
      end

      context "and id = vm_start" do
        before do
          @id = "vm_start"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'start'
        it_behaves_like 'default case'
      end

      context "and id = vm_guest_standby" do
        before do
          @id = "vm_guest_standby"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'standby_guest'
        it_behaves_like 'default case'
      end

      context "and id = vm_guest_shutdown" do
        before do
          @id = "vm_guest_shutdown"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'shutdown_guest'
        it_behaves_like 'default case'
      end

      context "and id = vm_guest_restart" do
        before do
          @id = "vm_guest_restart"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'reboot_guest'
        it_behaves_like 'default case'
      end

      context "and id = vm_stop" do
        before do
          @id = "vm_stop"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'stop'
        it_behaves_like 'default case'
      end

      context "and id = vm_reset" do
        before do
          @id = "vm_reset"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'reset'
        it_behaves_like 'default case'
      end

      context "and id = vm_suspend" do
        before do
          @id = "vm_suspend"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'suspend'
        it_behaves_like 'default case'
      end

      ["vm_retire", "vm_retire_now"].each do | button_id |
        context "and id = #{button_id}" do
          before { @id = button_id }
          it "when VM is already retired" do
            @record.stub(:retired => true)
            subject.should == "VM is already retired"
          end
          it_behaves_like 'default case'
        end
      end

      context "and id = vm_scan" do
        before do
          @id = "vm_scan"
          @record.stub(:has_active_proxy? => true)
        end
        it "when no active proxy" do
          @record.stub(:has_active_proxy? => false)
          subject.should == "No active SmartProxies found to analyze this VM"
        end
        it_behaves_like 'default case'
      end

      context "and id = vm_timeline" do
        before do
          @id = "vm_timeline"
          @record.stub(:has_events?).and_return(true)
        end
        it_behaves_like 'record without ems events and policy events', 'No Timeline data has been collected for this VM'
        it_behaves_like 'default case'
      end

      context "snapshot buttons" do
        before(:each) do
          @record = FactoryGirl.create(:vm_vmware, :vendor => "vmware")
        end

        context "and id = vm_snapshot_add" do
          before do
            @id = "vm_snapshot_add"
            @record.stub(:is_available?).with(:create_snapshot).and_return(false)
          end

          context "when number of snapshots <= 0" do
            before { @record.stub(:is_available?).with(:create_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'create_snapshot'
          end

          context "when number of snapshots > 0" do
            before do
              @record.stub(:number_of).with(:snapshots).and_return(4)
              @record.stub(:is_available?).with(:create_snapshot).and_return(false)
            end

            it_behaves_like 'record with error message', 'create_snapshot'

            it "when no available message but active" do
                @record.stub(:is_available?).with(:create_snapshot).and_return(false)
                @active = true
              subject.should == "The VM is not connected to a Host"
            end
          end
          it_behaves_like 'default true_case'
        end

        context "and id = vm_snapshot_delete" do
          before { @id = "vm_snapshot_delete" }
          context "when with available message" do
            before { @record.stub(:is_available?).with(:remove_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'remove_snapshot'
          end
          context "when without snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'remove_snapshot'
          end
          context "when with snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'default case'
          end
        end

        context "and id = vm_snapshot_delete_all" do
          before { @id = "vm_snapshot_delete_all" }
          context "when with available message" do
            before { @record.stub(:is_available?).with(:remove_all_snapshots).and_return(false) }
            it_behaves_like 'record with error message', 'remove_all_snapshots'
          end
          context "when without snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'remove_all_snapshots'
          end
          context "when with snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'default case'
          end
        end

        context "id = vm_snapshot_revert" do
          before { @id = "vm_snapshot_revert" }
          context "when with available message" do
            before { @record.stub(:is_available?).with(:revert_to_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'revert_to_snapshot'
          end
          context "when without snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'revert_to_snapshot'
          end
          context "when with snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'default case'
          end
        end
      end
    end # end of Vm class

    context "Disable Snapshot buttons for RHEV VMs" do
      before(:each) { @record = FactoryGirl.create(:vm_redhat) }

      ['vm_snapshot_add','vm_snapshot_delete', 'vm_snapshot_delete_all', 'vm_snapshot_revert'].each do |b|
        it "button #{b}" do
          res = build_toolbar_disable_button(b)
          res.should be_true
          res.should include("not supported")
        end
      end
    end

    context "Disable Retire button for already retired VMs and Instances" do
      it "button vm_retire_now" do
        @record = FactoryGirl.create(:vm_redhat, :retired => true)
        res = build_toolbar_disable_button("vm_retire_now")
        res.should be_true
        res.should include("already retired")
      end

      it "button instance_retire_now" do
        @record = FactoryGirl.create(:vm_amazon, :retired => true)
        res = build_toolbar_disable_button("instance_retire_now")
        res.should be_true
        res.should include("already retired")
      end
    end

  end #end of disable button

  describe "#get_record_cls"  do
    subject { get_record_cls(record) }
    context "when record not exist" do
      let(:record) { nil }
      it { should == "NilClass" }
    end

    context "when record is array" do
      let(:record) { ["some", "thing"] }
      it { should  == record.class.name }
    end

    context "when record is valid" do
      [HostRedhat].each do |c|
        it "and with #{c}" do
          record = c.new
          get_record_cls(record).should eql(record.class.base_class.to_s)
        end
      end

      it "and with 'VmOrTemplate'" do
        record = TemplateVmware.new
        get_record_cls(record).should eql(record.class.base_model.to_s)
      end

      it "otherwise" do
        record = Job.new
        get_record_cls(record).should eql(record.class.to_s)
      end
    end
  end

  describe "#build_toolbar_select_button" do
    before :each do
      @gtl_type = 'list'
      @settings = {
        :views => {
          :compare      => 'compressed',
          :drift        => 'compressed',
          :compare_mode => 'exists',
          :drift_mode   => 'exists',
          :treesize     => '32'
        }
      }
    end
    subject { build_toolbar_select_button(id) }

    ['list', 'tile', 'grid'].each do |g|
      it "when with view_#{g}" do
        @gtl_type = g
        build_toolbar_select_button("view_#{g}").should be_true
      end
    end

    it "when with tree_large" do
      @settings[:views][:treesize] = 32
      build_toolbar_select_button("tree_large").should be_true
    end

    it "when with tree_small" do
      @settings[:views][:treesize] = 16
      build_toolbar_select_button("tree_small").should be_true
    end

    context  "when with 'compare_compressed'" do
      let(:id) { "compare_compressed" }
      it { should be_true }
    end

    context  "when with 'drift_compressed'" do
      let(:id) { "drift_compressed" }
      it { should be_true }
    end

    context  "when with 'compare_all'" do
      let(:id) { "compare_all" }
      it { should be_true }
    end

    context  "when with 'drift_all'" do
      let(:id) { "drift_all" }
      it { should be_true }
    end

    context  "when with 'comparemode_exists" do
      let(:id) { "comparemode_exists" }
      it { should be_true }
    end

    context  "when with 'driftmode_exists" do
      let(:id) { "driftmode_exists" }
      it { should be_true }
    end

  end

  describe "#build_toolbar_save_button" do
    before do
      @record = double(:id => 'record_id_xxx_001', :class => 'record_xxx_class')
      btn_num = "x_button_id_001"
      desc = 'the description for the button'
      @item = { :button=>"custom_#{btn_num}",
                    :url=>"button",
                    :url_parms=>"?id=#{@record.id}&button_id=#{btn_num}&cls=#{@record.class}&pressed=custom_button&desc=#{desc}"
      }
      @tb_buttons = Hash.new
      @parent = nil
      Object.any_instance.stub(:query_string).and_return("")
      allow_message_expectations_on_nil
    end

    context "names the button" do
      subject {
        build_toolbar_save_button(@tb_buttons, @item, @parent)
        @tb_buttons
      }

      it "as item[:buttonSelect] when item[:buttonTwoState] does not exist" do
        @item[:buttonSelect] = 'tree_large'
        subject.should have_key("tree_large")
      end

      it "as item[:button] when both item[:buttonTwoState] and item[:buttonSelect] not exist" do
        subject.should have_key("#{@item[:button]}")
      end

      it "prefixed with 'parent__' when parent is passed in" do
        @parent = "testing"
        subject.should have_key("#{@parent}__#{@item[:button]}")
      end
    end

    context "saves the item info by the same key" do
      subject {
        build_toolbar_save_button(@tb_buttons, @item)
        @tb_buttons[@item[:button]]
      }

      it "when item[:hidden] exists" do
        @item[:hidden] = 1
        subject.should have_key(:hidden)
      end

      it "when both parent and item[:title] exists" do
        parent = "Vm"
        @item[:title] = "Power On this VM"
        build_toolbar_save_button(@tb_buttons, @item, parent)
        @tb_buttons["#{parent}__#{@item[:button]}"].should have_key(:title)
      end

      it "when item[:url_parms] exists" do
        subject.should have_key(:url_parms)
      end

      it "when item[:confirm] exists" do
        @item[:confirm] = 'Are you sure?'
        subject.should have_key(:confirm )
      end

      it "when item[:onwhen] exists" do
        @item[:onwhen] = '1+'
        subject.should have_key(:onwhen )
      end
    end

    context "when item[:url] exists" do
      subject {
        build_toolbar_save_button(@tb_buttons, @item)
        @tb_buttons[@item[:button]]
      }

      it "gets rid of first directory and anything after last slash when button is 'view_grid', 'view_tile' or 'view_list'" do
        @item = { :button => 'view_list', :url => '/some/path/to/the/testing/code' }
        subject.should include( :url => '/path/to/the/testing' )
      end

      it "saves the value as it is otherwise" do
        subject.should have_key(:url)
      end
    end
  end

  describe "#field_to_col" do
    subject { field_to_col(field) }
    context "when field likes 'Vm.hardware.disks-size'" do
      let(:field) { "Vm.hardware.disks-size" }
      it { should == "disks.size" }
    end

    context "when field likes 'disks-size'" do
      let(:field) { "disks-size" }
      it { should == "size" }
    end

    context "when field likes 'size'" do
      let(:field) { "size" }
      it { should be_false }
    end

    context "when field likes 'Vm.size'" do
      let(:field) { "Vm.size" }
      it { should_not == "size" }
    end
  end

  context "#get_vmdb_config" do
    it "Replaces calls to VMDB::Config.new in the views/controllers" do
      get_vmdb_config.should equal(@vmdb_config)
    end
  end

  context "#to_cid" "(id)" do
    it "converts record id to compressed id" do
      to_cid(12000000000056).should == '12r56'
    end
  end

  context "#from_cid" "(cid)" do
    it "converts compressed id to record id" do
      from_cid("12r56").should == 12000000000056
    end
  end

  context "#title_from_layout" do
    let(:title) { I18n.t('product.name') }
    subject { title_from_layout(@layout) }

    it "when layout is blank" do
      @layout = ""
      subject.should == title
    end

    it "when layout = 'miq_server'" do
      @layout = "miq_server"
      subject.should == title + ": Servers"
    end

    it "when layout = 'usage'" do
      @layout = "usage"
      subject.should == title + ": VM Usage"
    end

    it "when layout = 'scan_profile'" do
      @layout = "scan_profile"
      subject.should == title + ": Analysis Profiles"
    end

    it "when layout = 'miq_policy_rsop'" do
      @layout = "miq_policy_rsop"
      subject.should == title + ": Policy Simulation"
    end

    it "when layout = 'all_ui_tasks'" do
      @layout = "all_ui_tasks"
      subject.should == title + ": All UI Tasks"
    end

    it "when layout = 'rss'" do
      @layout = "rss"
      subject.should == title + ": RSS"
    end

    it "when layout = 'management_system'" do
      @layout = "management_system"
      subject.should == title + ": Management Systems"
    end

    it "when layout = 'storage_manager'" do
      @layout = "storage_manager"
      subject.should == title + ": Storage - Storage Managers"
    end

    it "when layout = 'ops'" do
      @layout = "ops"
      subject.should == title + ": Configuration"
    end

    it "when layout = 'pxe'" do
      @layout = "pxe"
      subject.should == title + ": PXE"
    end

    it "when layout = 'vm_or_template'" do
      @layout = "vm_or_template"
      subject.should == title + ": Workloads"
    end

    it "when layout likes 'miq_ae_*'" do
      @layout = "miq_ae_some_thing"
      subject.should == title + ": Automate"
    end

    it "when layout likes 'miq_policy*'" do
      @layout = "miq_policy_some_thing"
      subject.should == title + ": Control"
    end

    it "when layout likes 'miq_capacity*'" do
      @layout = "miq_capacity_some_thing"
      subject.should == title + ": Optimize"
    end

    it "when layout likes 'miq_request*'" do
      @layout = "miq_request_some_thing"
      subject.should == title + ": Requests"
    end

    it "when layout likes 'cim_*' or 'snia_*'" do
      @layout = "cim_base_storage_extent"
      subject.should == title  + ": Storage - #{ui_lookup(:tables=>@layout)}"
    end

    it "otherwise" do
      @layout = "xxx"
      subject.should == title  + ": #{ui_lookup(:tables=>@layout)}"
    end
 end

  context "#controller_model_name" do
    it "returns the model's title" do
      controller_model_name("OntapFileShare").should == "Storage - File Share"
      controller_model_name("CimStorageExtent").should == "Storage - Extent"
    end
  end

  context "#is_browser_ie7?" do
    it "when browser's explorer version 7.x" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('explorer')
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :version).and_return('7.10')
      is_browser_ie7?.should be_true
    end

    it "when browser's NOT explorer version 7.x" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('explorer')
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :version).and_return('6.10')
      is_browser_ie7?.should be_false
    end
  end

  context "#is_browser_ie?" do
    it "when browser's explorer" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('explorer')
      is_browser_ie?.should be_true
    end

    it "when browser's NOT explorer" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('safari')
      is_browser_ie?.should be_false
    end
  end

  context "#is_browser?" do
    it "when browser's name is in the list" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('safari')
      is_browser?(["firefox","opera","safari"]).should be_true
    end

    it "when browser's name is NOT in the list" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('explorer')
      is_browser?(["firefox","opera","safari"]).should be_false
    end
  end

  context "#is_browser_os?" do
    it "when browser's OS is in the list" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :os).and_return('windows')
      is_browser_os?(["windows", "linux"]).should be_true
    end

    it "when browser's OS is NOT in the list" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :os).and_return('macos')
      is_browser_os?(["windows", "linux"]).should be_false
    end
  end

  context "#browser_info" do
    it "checks by name when called with NO argument" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('checked_by_name')
      browser_info( ).should == 'checked_by_name'
    end

    it "checks by 'a_type' when called with 'a_type'" do
      type = :a_type
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, type).and_return('checked_by_a_type')
      browser_info(type).should == 'checked_by_a_type'
    end
  end

  describe "#javascript_for_timer_type" do
    subject { javascript_for_timer_type(timer_type) }

    context "when timer_type == nil" do
      let(:timer_type) { nil }
      specify { subject.should be_empty }
    end

    context "when timer_type == 'Monthly'" do
      let(:timer_type) { 'Monthly' }
      it { should include("$('\#weekly_span').hide();") }
      it { should include("$('\#daily_span').hide();") }
      it { should include("$('\#hourly_span').hide();") }
      it { should include("$('\#monthly_span').show();") }
    end

    context "when timer_type == 'Weekly'" do
      let(:timer_type) { 'Weekly' }
      it { should include("$('\#daily_span').hide();") }
      it { should include("$('\#hourly_span').hide();") }
      it { should include("$('\#monthly_span').hide();") }
      it { should include("$('\#weekly_span').show();") }
    end

    context "when timer_type == 'Daily'" do
      let(:timer_type) { 'Daily' }
      it { should include("$('\#hourly_span').hide();") }
      it { should include("$('\#monthly_span').hide();") }
      it { should include("$('\#weekly_span').hide();") }
      it { should include("$('\#daily_span').show();") }
    end

    context "when timer_type == 'Hourly'" do
      let(:timer_type) { 'Hourly' }
      it { should include("$('\#daily_span').hide();") }
      it { should include("$('\#monthly_span').hide();") }
      it { should include("$('\#weekly_span').hide();") }
      it { should include("$('\#hourly_span').show();") }
    end

    context "when timer_type == 'something_else'" do
      let(:timer_type) { 'something_else' }
      it { should include("$('\#daily_span').hide();") }
      it { should include("$('\#hourly_span').hide();") }
      it { should include("$('\#monthly_span').hide();") }
      it { should include("$('\#weekly_span').hide();") }
    end
  end

  describe "#javascript_for_miq_button_visibility" do
    subject { javascript_for_miq_button_visibility(display) }
    context "when display == true" do
      let(:display) { true }
      it { should == "miqButtons('show');" }
    end

    context "when dsiplay == false" do
      let(:display) { false }
      it { should == "miqButtons('hide');" }
    end
  end

  context "#javascript_for_toolbar_reload" do
    let(:test_tab)    {"some_center_tb"}
    let(:test_buttons) {"x_button"}
    let(:test_xml)    {"x_xml"}
    subject { javascript_for_toolbar_reload(test_tab, test_buttons, test_xml)}

    it { should include("miq_toolbars.#{test_tab}.obj.unload();") }
    it { should include("#{test_tab} = new dhtmlXToolbarObject('#{test_tab}', 'miq_blue');") }
    it { should include("buttons: #{test_buttons}") }
    it { should include("xml: \"#{test_xml}\"") }
    it { should include("miqInitToolbar(miq_toolbars['some_center_tb']);") }
  end

  context "#javascript_set_value" do
    let(:element_id)    {"text_field"}
    let(:element_value) {"something"}
    subject { javascript_set_value(element_id, element_value)}

    it { should eq("$('#text_field').val('something');") }
  end

  context "#set_edit_timer_from_schedule" do
    before(:each) do
      @edit = {:tz => 'Eastern Time (US & Canada)', :new => Hash.new}
      @interval = '3'
      @date = "6/28/2012"
      @hour = "0#{11-4}"
      @min = "14"
      @run_at = {:start_time => "2012-06-28 11:14:00".to_time(:utc),
                 :interval   => {:value => @interval}}
      @schedule = double( :run_at => @run_at )
    end

    describe "when schedule.run_at == nil" do
      it "sets defaults" do
        schedule = double(:run_at => nil)
        set_edit_timer_from_schedule schedule
        @edit[:new].should include(
          :timer_typ => "Once",
          :start_hour => "00",
          :start_min => "00"
        )
      end
    end

    describe "when schedule.run_at != nil" do
      it "sets values as monthly" do
        @run_at[:interval][:unit] = 'monthly'
        set_edit_timer_from_schedule @schedule
        @edit[:new].should include(
          :timer_typ => 'Monthly',
          :timer_months => @interval,
          :start_hour => @hour,
          :start_min => @min,
          :start_date => @date
        )
        @edit[:new].should_not include( :timer_months => '1' )
      end

      it "sets values as weekly" do
        @run_at[:interval][:unit] = 'weekly'
        set_edit_timer_from_schedule @schedule
        @edit[:new].should include(
          :timer_typ => 'Weekly',
          :timer_weeks => @interval,
          :start_hour => @hour,
          :start_min => @min,
          :start_date => @date
        )
        @edit[:new].should_not include( :timer_weeks => '1' )
      end

      it "sets values as daily" do
        @run_at[:interval][:unit] = 'daily'
        set_edit_timer_from_schedule @schedule
        @edit[:new].should include(
          :timer_typ => 'Daily',
          :timer_days => @interval,
          :start_hour => @hour,
          :start_min => @min,
          :start_date => @date
        )
        @edit[:new].should_not include( :timer_days => '1' )
      end

      it "sets values as hourly" do
        @run_at[:interval][:unit] = 'hourly'
        set_edit_timer_from_schedule @schedule
        @edit[:new].should include(
          :timer_typ => 'Hourly',
          :timer_hours => @interval,
          :start_hour => @hour,
          :start_min => @min,
          :start_date => @date
        )
        @edit[:new].should_not include( :timer_hours => '1' )
      end
    end
  end

  context "#perf_parent?" do
    it "when model != 'VmOrTemplate'" do
      @perf_options = {:model => 'OntapVolumeDerivedMetric'}
      perf_parent?.should be_false
    end

    it "when model == 'VmOrTemplate' and typ == 'realtime'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'realtime'}
      perf_parent?.should be_false
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent is 'Host'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => 'Host'}
      perf_parent?.should be_true
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent is 'EmsCluster'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => 'EmsCluster'}
      perf_parent?.should be_true
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent is 'invalid parent'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => 'invalid parent'}
      perf_parent?.should be_false
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent == nil" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => nil}
      perf_parent?.should be_false
    end
  end

  context "#perf_compare_vm?" do
    it "when model != 'OntapLogicalDisk'" do
      @perf_options = {:model => 'OntapVolumeDerivedMetric'}
      perf_compare_vm?.should be_false
    end

    it "when model == 'OntapLogicalDisk' and typ == 'realtime'" do
      @perf_options = {:model => 'OntapLogicalDisk', :typ => 'realtime'}
      perf_compare_vm?.should be_false
    end

    it "when model == 'OntapLogicalDisk', typ != 'realtime' and compare_vm == nil" do
      @perf_options = {:model => 'OntapLogicalDisk', :typ => 'Daily', :compare_vm => nil}
      perf_compare_vm?.should be_false
    end

    it "when model == 'OntapLogicalDisk', typ != 'realtime' and compare_vm != nil" do
      @perf_options = {:model => 'OntapLogicalDisk', :typ => 'Daily', :compare_vm => 'something'}
      perf_compare_vm?.should be_true
    end
  end

  context "#model_report_type" do
    it "when model == nil" do
      model_report_type(nil).should be_false
    end

    it "when model likes '...Performance' or '...MetricsRollup'" do
      model_report_type("VmPerformance").should == :performance
      model_report_type("OntapVolumeMetricsRollup").should == :performance
    end

    it "when model == VimPerformanceTrend" do
      model_report_type("VimPerformanceTrend").should == :trend
    end

    it "when model == Chargeback" do
      model_report_type("Chargeback").should == :chargeback
    end
  end

  context "tree related methods" do
    before do
      @sb = { :active_tree => :svcs_tree,
              :trees => { :svcs_tree => { :tree => :svcs_tree }}}
    end

    it "#x_node_set" do
      @sb[:trees][:svcs_tree]      = {:active_node => 'root'}
      @sb[:trees][:vm_filter_tree] = {:active_node => 'abc'}

      x_node_set('def', :vm_filter_tree)
      @sb[:trees][:svcs_tree][:active_node].should      == 'root'
      @sb[:trees][:vm_filter_tree][:active_node].should == 'def'

      x_node_set(nil, :vm_filter_tree)
      @sb[:trees][:svcs_tree][:active_node].should      == 'root'
      @sb[:trees][:vm_filter_tree][:active_node].should be_nil

      x_node_set('', :vm_filter_tree)
      @sb[:trees][:svcs_tree][:active_node].should      == 'root'
      @sb[:trees][:vm_filter_tree][:active_node].should == ''
    end

    it "#x_node=" do
      helper.x_node = 'root'
      @sb[:trees][:svcs_tree][:active_node].should == 'root'

      helper.x_node = nil
      @sb[:trees][:svcs_tree][:active_node].should be_nil

      helper.x_node = ''
      @sb[:trees][:svcs_tree][:active_node].should == ''
    end

    context "#x_node" do
      it "without tree param" do
        @sb[:trees][:svcs_tree] = {:active_node => 'root'}
        x_node.should == 'root'

        @sb[:trees][:svcs_tree] = {:active_node => nil}
        x_node.should be_nil

        @sb[:trees][:svcs_tree] = {:active_node => ''}
        x_node.should == ''
      end

      it "with tree param" do
        @sb[:trees][:svcs_tree]      = {:active_node => 'root'}
        @sb[:trees][:vm_filter_tree] = {:active_node => 'abc'}

        x_node(:svcs_tree).should      == "root"
        x_node(:vm_filter_tree).should == "abc"
      end
    end

    context "#x_tree" do
      it "without tree param" do
        @sb[:trees][:vm_filter_tree] = {:tree => :vm_filter_tree}

        x_tree.should == @sb[:trees][:svcs_tree]
        @sb[:active_tree] = :vm_filter_tree
        x_tree.should == @sb[:trees][:vm_filter_tree]
      end

      it "with tree param" do
        @sb[:trees][:vm_filter_tree] = {:tree => :vm_filter_tree}
        @sb[:trees][:svcs_tree]      = {:tree => :svcs_tree}

        x_tree(:svcs_tree).should      == @sb[:trees][:svcs_tree]
        x_tree(:vm_filter_tree).should == @sb[:trees][:vm_filter_tree]
      end
    end

    it "#x_active_tree=" do
      helper.x_active_tree = 'vms_filter_tree'
      @sb[:active_tree].should == :vms_filter_tree

      helper.x_active_tree = 'svcs_tree'
      @sb[:active_tree].should == :svcs_tree
    end

    it "#x_active_tree" do
      x_active_tree.should == :svcs_tree
      @sb[:active_tree] = :vm_filter_tree
      x_active_tree.should == :vm_filter_tree
    end

    context "#x_tree_init" do
      it "does not replace existing trees" do
        x_tree_init(:svcs_tree, :xxx, "XXX")

        @sb[:trees][:svcs_tree].should == { :tree => :svcs_tree }
      end

      it "has default values" do
        x_tree_init(:vm_filter_tree, :vm_filter, "Vm")

        @sb[:trees][:vm_filter_tree].should == {
          :tree       => :vm_filter_tree,
          :type       => :vm_filter,
          :leaf       => "Vm",
          :add_root   => true,
          :open_nodes => []
        }
      end

      it "can override default values" do
        x_tree_init(:vm_filter_tree, :vm_filter, "Vm",
          :add_root   => false,
          :open_nodes => [:a],
          :open_all   => true,
          :full_ids   => true
        )

        @sb[:trees][:vm_filter_tree].should == {
          :tree       => :vm_filter_tree,
          :type       => :vm_filter,
          :leaf       => "Vm",
          :add_root   => false,
          :open_nodes => [:a],
          :open_all   => true,
          :full_ids   => true
        }
      end
    end

    it "#x_tree_history" do
      @sb = { :history => { :svcs_tree => %w(service1 service2 service3) },
              :active_tree => :svcs_tree }
      x_tree_history.should == %w(service1 service2 service3)
    end
  end

  describe "truncate text for quad icons" do

    ["front", "middle", "back"].each do |trunc|

      context "remove #{trunc} of text" do

        before(:each) do
          @settings = {:display=>{:quad_truncate=>trunc[0]}}
        end

        it "when value is nil" do
          text = truncate_for_quad(nil)
          text.should be_nil
        end

        it "when value is < 13 long" do
          text = truncate_for_quad("Test")
          text.should == "Test"
        end

        it "when value is 12 long" do
          text = truncate_for_quad("ABCDEFGHIJKL")
          text.should == "ABCDEFGHIJKL"
        end

        it "when value is 13 long" do
          text = truncate_for_quad("ABCDEooo12345")
          text.should == case trunc[0]
                           when "f"; "...DEooo12345"
                           when "m"; "ABCDE...12345"
                           when "b"; "ABCDEooo12..."
                         end
        end

        it "when value is 25 long" do
          text = truncate_for_quad("ABCDEooooooooooooooo12345")
          text.should == case trunc[0]
                           when "f"; "...ooooo12345"
                           when "m"; "ABCDE...12345"
                           when "b"; "ABCDEooooo..."
                         end
        end
      end

    end

  end

  describe "generate custom toolbar file names" do

    context "for classic (non-explorer) CI main summary screens" do

      before(:each) do
        @lastaction = "show"
        @record = true
      end

      ["miq_template","ems_cloud","ems_cluster","ems_infra","host","storage"].each do |table|

        it "for table #{table}" do
          @layout = table
          @display = "main"
          text = custom_toolbar_filename
          text.should == "custom_buttons_tb"
        end

      end

      # Just a few tables that don't have custom toolbars
      ["ems_events","storage_managers"].each do |table|

        it "for table #{table}" do
          @layout = table
          text = custom_toolbar_filename
          text.should be_nil
        end

      end

    end

    context "for classic (non-explorer) CI non-main summary screens" do

      before(:each) do
        @lastaction = "show"
        @record = true
      end

      ["miq_template","ems_cluster","host","storage","management_system"].each do |table|

        it "for table #{table}" do
          @layout = table
          @display = "not_main"
          text = custom_toolbar_filename
          text.should be_nil
        end

      end

    end

    context "for classic (non-explorer) CI list view screens" do

      before(:each) do
        @lastaction = "show_list"
        @record = true
      end

      ["miq_template","ems_cluster","host","storage","management_system"].each do |table|

        it "for table #{table}" do
          @layout = table
          text = custom_toolbar_filename
          text.should be_nil
        end

      end

      # Just a few tables that don't have custom toolbars
      ["ems_events","storage_managers"].each do |table|

        it "for table #{table}" do
          @layout = table
          text = custom_toolbar_filename
          text.should be_nil
        end

      end

    end

    context "for explorer-based screens" do

      before(:each) do
        @explorer = true
        @sb = {:active_tree => "my_tree",
               :trees       => {"my_tree" => {:active_node=>nil}}
              }
      end

      it "for non custom toolbar controller" do
        helper.stub(:params) { {:controller => "policy"} }
        text = helper.custom_toolbar_filename
        text.should be_nil
      end

      ["vm_or_template","service"].each do |table|

        it "for #{table} controller on root node" do
          @sb[:trees][@sb[:active_tree]][:active_node] = "root"
          helper.stub(:params) { {:controller => table} }
          text = helper.custom_toolbar_filename
          text.should == "blank_view_tb"
        end

        it "for #{table} controller on record node summary screen" do
          @sb[:trees][@sb[:active_tree]][:active_node] = "v-1r35"
          @display = "main"
          @record = true
          helper.stub(:params) { {:controller => table} }
          text = helper.custom_toolbar_filename
          text.should == "custom_buttons_tb"
        end

        it "for #{table} controller on record node, but not summary screen" do
          @sb[:trees][@sb[:active_tree]][:active_node] = "v-1r35"
          @display = "not_main"
          @record = true
          helper.stub(:params) { {:controller => table} }
          text = helper.custom_toolbar_filename
          text.should == "blank_view_tb"
        end

      end

    end

    context "#center_toolbar_filename_classic" do
      it "miq_request summary screen" do
        @lastaction = "show"
        @view = true
        @layout = "miq_request_vm"
        toolbar_name = center_toolbar_filename_classic
        toolbar_name.should == "miq_request_center_tb"
      end

      it "miq_request list screen" do
        @lastaction = "show_list"
        @view = true
        @layout = "miq_request_vm"
        toolbar_name = center_toolbar_filename_classic
        toolbar_name.should == "miq_requests_center_tb"
      end
    end

    context "#center_div_height" do
      it "calculates height for center div" do
        @winH = 800
        max = 627
        min = 200
        height = @winH < max ? min : @winH - (max - min)
        res = center_div_height
        res.should == height

        max = 757
        min = 400
        height = @winH < max ? min : @winH - (max - min)
        res = center_div_height(false, 400)
        res.should == height
      end
    end
  end

  describe '#pressed2model_action' do
    examples = {
      'miq_template_bar' => ['miq_template', 'bar'],
      'boo_far'          => ['boo', 'far'],
      'boo_far_bar'      => ['boo', 'far_bar'],
    }

    examples.each_pair do |input,output|
      it "gives '#{output}' on '#{input}'" do
        helper.pressed2model_action(input).should == output
      end
    end
  end

  describe "generate explorer toolbar file names" do
    context "#center_toolbar_filename_automate" do
      before do
        @sb = {:active_tree => :ae_tree,
               :trees       => {:ae_tree => {:tree => :ae_tree}}}
      end

      it "should return domains toolbar on root node" do
        x_node_set('root', :ae_tree)
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_domains_center_tb")
      end

      it "should return namespaces toolbar on domain node" do
        n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :priority => 10)
        x_node_set("aen-#{n1.id}", :ae_tree)
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_domain_center_tb")
      end

      it "should return namespace toolbar on namespace node" do
        n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :parent_id => 1)
        x_node_set("aen-#{n1.id}", :ae_tree)
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_namespace_center_tb")
      end

      it "should return tab specific toolbar on class node" do
        n1 = FactoryGirl.create(:miq_ae_namespace, :name => 'ns1', :parent_id => 1)
        c1 = FactoryGirl.create(:miq_ae_class, :namespace_id => n1.id, :name => "foo")
        x_node_set("aec-#{c1.id}", :ae_tree)

        @sb[:active_tab] = "props"
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_class_center_tb")

        @sb[:active_tab] = "methods"
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_methods_center_tb")

        @sb[:active_tab] = "schema"
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_fields_center_tb")

        @sb[:active_tab] = ""
        toolbar_name = center_toolbar_filename_automate
        toolbar_name.should eq("miq_ae_instances_center_tb")
      end
    end
  end

  describe "update_paging_url_parms", :type => :request do

    context "when the given parameter is a hash" do
      before do
        get("/vm/show_list/100", "bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5"\
           "&page=2&sb_controller=host")
        Object.any_instance.stub(:query_string).and_return(@request.query_string)
        allow_message_expectations_on_nil
      end

      it "updates the query string with the given hash value and returns the full url path" do
        update_paging_url_parms("show_list", :page => 1).should eq("/vm/show_list/100?bc=VMs+running+on+2014-08-25"\
          "&menu_click=Display-VMs-on_2-6-5&page=1&sb_controller=host")
      end
    end
  end

  describe "update_url_parms", :type => :request do

    context "when the given parameter exists in the request query string" do
      before do
        get("/vm/show_list/100", "type=grid")
        Object.any_instance.stub(:query_string).and_return(@request.query_string)
        Object.any_instance.stub(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "updates the query string with the given parameter value" do
        update_url_parms("?type=list").should eq("?type=list")
      end
    end

    context "when the given parameters do not exist in the request query string" do
      before do
        get("/vm/show_list/100")
        Object.any_instance.stub(:query_string).and_return(@request.query_string)
        Object.any_instance.stub(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "adds the params in the query string" do
        update_url_parms("?refresh=y&type=list").should eq("?refresh=y&type=list")
      end
    end

    context "when the request query string has a few specific params to be retained" do
      before do
        get("/vm/show_list/100", "bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5"\
          "&sb_controller=host")
        Object.any_instance.stub(:query_string).and_return(@request.query_string)
        Object.any_instance.stub(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "retains the specific parameters and adds the new one" do
        update_url_parms("?type=list").should eq("?bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5"\
          "&sb_controller=host&type=list")
      end
    end

    context "when the request query string has a few specific params to be excluded" do
      before do
        get("/vm/show_list/100", "page=1")
        Object.any_instance.stub(:query_string).and_return(@request.query_string)
        Object.any_instance.stub(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "excludes specific parameters and adds the new one" do
        update_url_parms("?type=list").should eq("?type=list")
      end
    end
  end

  context "#title_for_clusters" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Clusters / Deployment Roles' when there are both openstack & non-openstack clusters" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)
      FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = title_for_clusters
      result.should eq("Clusters / Deployment Roles")
    end

    it "returns 'Clusters' when there are only non-openstack clusters" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)

      result = title_for_clusters
      result.should eq("Clusters")
    end

    it "returns 'Deployment Roles' when there are only openstack clusters" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = title_for_clusters
      result.should eq("Deployment Roles")
    end
  end

  context "#title_for_cluster" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Cluster' for non-openstack cluster" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)

      result = title_for_cluster
      result.should eq("Cluster")
    end

    it "returns 'Deployment Role' for openstack cluster" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = title_for_cluster
      result.should eq("Deployment Role")
    end
  end

  context "#title_for_cluster_record" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Cluster' for non-openstack host" do
      cluster = FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)

      result = title_for_cluster_record(cluster)
      result.should eq("Cluster")
    end

    it "returns 'Deployment Role' for openstack host" do
      cluster = FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = title_for_cluster_record(cluster)
      result.should eq("Deployment Role")
    end
  end

  context "#title_for_hosts" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Hosts / Nodes' when there are both openstack & non-openstack hosts" do
      FactoryGirl.create(:host_vmware_esx, :ems_id => @ems1.id)
      FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)

      result = title_for_hosts
      result.should eq("Hosts / Nodes")
    end

    it "returns 'Hosts' when there are only non-openstack hosts" do
      FactoryGirl.create(:host_vmware_esx, :ems_id => @ems1.id)

      result = title_for_hosts
      result.should eq("Hosts")
    end

    it "returns 'Nodes' when there are only openstack hosts" do
      FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)

      result = title_for_hosts
      result.should eq("Nodes")
    end
  end

  context "#title_for_host" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Host' for non-openstack host" do
      FactoryGirl.create(:host_vmware, :ems_id => @ems1.id)

      result = title_for_host
      result.should eq("Host")
    end

    it "returns 'Node' for openstack host" do
      FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)

      result = title_for_host
      result.should eq("Node")
    end
  end

  context "#title_for_host_record" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Host' for non-openstack host" do
      host = FactoryGirl.create(:host_vmware, :ems_id => @ems1.id)

      result = title_for_host_record(host)
      result.should eq("Host")
    end

    it "returns 'Node' for openstack host" do
      host = FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)

      result = title_for_host_record(host)
      result.should eq("Node")
    end
  end

  context "#start_page_allowed?" do
    def role_allows(_)
      true
    end

    it "should return true for storage start pages when product flag is set" do
      cfg = VMDB::Config.new("vmdb")
      cfg.config.store_path(:product, :storage, true)
      VMDB::Config.stub(:new).and_return(cfg)
      result = start_page_allowed?("cim_storage_extent_show_list")
      result.should be_true
    end

    it "should return false for storage start pages when product flag is not set" do
      result = start_page_allowed?("cim_storage_extent_show_list")
      result.should be_false
    end

    it "should return true for containers start pages when product flag is set" do
      cfg = VMDB::Config.new("vmdb")
      cfg.config.store_path(:product, :containers, true)
      VMDB::Config.stub(:new).and_return(cfg)
      result = start_page_allowed?("ems_container_show_list")
      result.should be_true
    end

    it "should return false for containers start pages when product flag is not set" do
      result = start_page_allowed?("ems_container_show_list")
      result.should be_false
    end

    it "should return true for host start page" do
      result = start_page_allowed?("host_show_list")
      result.should be_true
    end
  end
end
