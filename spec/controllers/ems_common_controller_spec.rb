def set_up_controller_for_show_method(controller, ems_id)
  controller.instance_variable_set(:@_params, {:display => "download_pdf", :id => ems_id})
  controller.instance_variable_set(:@settings, :views => {:vm_summary_cool => "summary"})
  allow(controller).to receive_messages(:record_no_longer_exists? => false)
  allow(controller).to receive(:drop_breadcrumb)
  allow(controller).to receive(:disable_client_cache)
  allow(controller).to receive_messages(:render_to_string => "")
  allow(controller).to receive(:send_data)
  allow(PdfGenerator).to receive(:pdf_from_string).with('', 'pdf_summary').and_return("")
end

describe EmsCloudController do
  context "::EmsCommon" do
    context "#get_form_vars" do
      it "check if the default port for openstack/openstack_infra/rhevm is set" do
        controller.instance_variable_set(:@edit, :new => {})
        controller.instance_variable_set(:@_params, :server_emstype => "openstack")
        controller.send(:get_form_vars)
        expect(assigns(:edit)[:new][:port]).to eq(5000)

        controller.instance_variable_set(:@_params, {:server_emstype => "openstack_infra"})
        controller.send(:get_form_vars)
        expect(assigns(:edit)[:new][:port]).to eq(5000)

        controller.instance_variable_set(:@_params, :server_emstype => "ec2")
        controller.send(:get_form_vars)
        expect(assigns(:edit)[:new][:port]).to be_nil
      end
    end

    context "#get_form_vars" do
      it "check if provider_region gets reset when provider type is changed on add screen" do
        controller.instance_variable_set(:@edit, :new => {})
        controller.instance_variable_set(:@_params, :server_emstype => "ec2")
        controller.instance_variable_set(:@_params, :provider_region => "some_region")

        controller.send(:get_form_vars)
        expect(assigns(:edit)[:new][:provider_region]).to eq("some_region")

        controller.instance_variable_set(:@_params, :server_emstype => "openstack")
        controller.send(:get_form_vars)
        expect(assigns(:edit)[:new][:provider_region]).to be_nil
      end
    end

    context "#form_field_changed" do
      before :each do
        set_user_privileges
      end

      it "form_div should be updated when server type is sent up" do
        controller.instance_variable_set(:@edit, :new => {}, :key => "ems_edit__new")
        session[:edit] = assigns(:edit)
        post :form_field_changed, :params => { :server_emstype => "rhevm", :id => "new" }
        expect(response.body).to include("form_div")
      end

      it "form_div should not be updated when other fields are sent up" do
        controller.instance_variable_set(:@edit, :new => {}, :key => "ems_edit__new")
        session[:edit] = assigns(:edit)
        post :form_field_changed, :params => { :name => "Test", :id => "new" }
        expect(response.body).not_to include("form_div")
      end
    end

    context "#set_record_vars" do
      context "strip leading/trailing whitespace from hostname/ipaddress" do
        after :each do
          set_user_privileges
          controller.instance_variable_set(:@edit, :new => {:name     => 'EMS 1',
                                                            :emstype  => @type,
                                                            :hostname => '  10.10.10.10  ',
                                                            :port     => '5000'},
                                                   :key => 'ems_edit__new')
          session[:edit] = assigns(:edit)
          controller.send(:set_record_vars, @ems)
          expect(@ems.hostname).to eq('10.10.10.10')
        end

        it "when adding cloud EMS" do
          @type = 'openstack'
          @ems  = ManageIQ::Providers::Openstack::CloudManager.new
        end

        it "when adding infra EMS" do
          @type = 'rhevm'
          @ems  = ManageIQ::Providers::Redhat::InfraManager.new
        end
      end
    end

    context "#update_button_validate" do
      context "when authentication_check" do
        let(:mocked_ems_cloud) { double(EmsCloud) }
        before(:each) do
          controller.instance_variable_set(:@_params, :id => "42", :type => "amqp")
          expect(controller).to receive(:find_by_id_filtered).with(EmsCloud, "42").and_return(mocked_ems_cloud)
          expect(controller).to receive(:set_record_vars).with(mocked_ems_cloud, :validate).and_return(mocked_ems_cloud)
        end

        it "successful flash message (unchanged)" do
          allow(controller).to receive_messages(:edit_changed? => false)
          expect(mocked_ems_cloud).to receive(:authentication_check).with("amqp", :save => true).and_return([true, ""])
          expect(controller).to receive(:add_flash).with(_("Credential validation was successful"))
          expect(controller).to receive(:render_flash)
          controller.send(:update_button_validate)
        end

        it "unsuccessful flash message (changed)" do
          allow(controller).to receive_messages(:edit_changed? => true)
          expect(mocked_ems_cloud).to receive(:authentication_check)
            .with("amqp", :save => false).and_return([false, "Invalid"])
          expect(controller).to receive(:add_flash).with(_("Credential validation was not successful: Invalid"), :error)
          expect(controller).to receive(:render_flash)
          controller.send(:update_button_validate)
        end
      end
    end

    context "#button" do
      before(:each) do
        set_user_privileges
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it "when Retire Button is pressed for a Cloud provider Instance" do
        allow(controller).to receive(:role_allows).and_return(true)
        vm = FactoryGirl.create(:vm_vmware)
        ems = FactoryGirl.create("ems_vmware")
        post :button, :params => { :pressed => "instance_retire", "check_#{vm.id}" => "1", :format => :js, :id => ems.id, :display => 'instances' }
        expect(response.status).to eq 200
        expect(response.body).to include('vm/retire')
      end
    end
  end

  describe "#show" do
    let(:provider_openstack) { FactoryGirl.create(:provider_openstack, :name => "Undercloud") }
    let(:ems_openstack) { FactoryGirl.create(:ems_openstack, :name => "overcloud", :provider => provider_openstack) }
    let(:pdf_options) { controller.instance_variable_get(:@options) }

    context "download pdf file" do
      before :each do
        set_up_controller_for_show_method(controller, ems_openstack.id)
        controller.send(:show)
      end

      it "should not contains string 'ManageIQ' in the title of summary report" do
        expect(pdf_options[:title]).not_to include('ManageIQ')
      end

      it "should match proper title of report" do
        expect(pdf_options[:title]).to eq('Cloud Provider (Openstack) "overcloud"')
      end
    end
  end
end

describe EmsContainerController do
  context "::EmsCommon" do
    it 'calculate_display_class correctly' do
      expect(controller.calculate_display_class("container_nodes", nil)).to eq(ContainerNode)
      expect(controller.calculate_display_class("cloud_tenants", nil)).to eq(CloudTenant)
      expect(controller.calculate_display_class(nil, "flavors")).to eq(Flavor)
      expect(controller.calculate_display_class(nil, "container_routes")).to eq(ContainerRoute)
    end

    context "#update" do
      it "updates provider with new token" do
        allow(MiqServer).to receive(:my_zone).and_return("default")
        set_user_privileges
        @ems = ManageIQ::Providers::Kubernetes::ContainerManager.create(:name => "k8s", :hostname => "10.10.10.1", :port => 5000)
        controller.instance_variable_set(:@edit,
                                         :new    => {:name         => @ems.name,
                                                     :emstype      => @ems.type,
                                                     :hostname     => @ems.hostname,
                                                     :port         => @ems.port,
                                                     :bearer_token => 'valid-token'},
                                         :key    => "ems_edit__#{@ems.id}",
                                         :ems_id => @ems.id)
        session[:edit] = assigns(:edit)
        post :update, :params => { :button => "save", :id => @ems.id, :type => @ems.type }
        expect(response.status).to eq(200)
        expect(ManageIQ::Providers::Kubernetes::ContainerManager.last.authentication_token("bearer"))
          .to eq("valid-token")
      end
    end

    context "#button" do
      before(:each) do
        set_user_privileges
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it "when VM Migrate is pressed for unsupported type" do
        allow(controller).to receive(:role_allows).and_return(true)
        vm = FactoryGirl.create(:vm_microsoft)
        post :button, :params => { :pressed => "vm_migrate", :format => :js, "check_#{vm.id}" => "1" }
        expect(controller.send(:flash_errors?)).to be_truthy
        expect(assigns(:flash_array).first[:message]).to include('does not apply')
      end

      let(:ems)     { FactoryGirl.create(:ext_management_system) }
      let(:storage) { FactoryGirl.create(:storage) }

      it "when VM Migrate is pressed for supported type" do
        allow(controller).to receive(:role_allows).and_return(true)
        vm = FactoryGirl.create(:vm_vmware, :storage => storage, :ext_management_system => ems)
        post :button, :params => { :pressed => "vm_migrate", :format => :js, "check_#{vm.id}" => "1" }
        expect(controller.send(:flash_errors?)).not_to be_truthy
      end

      it "when VM Migrate is pressed for supported type" do
        allow(controller).to receive(:role_allows).and_return(true)
        vm = FactoryGirl.create(:vm_vmware)
        post :button, :params => { :pressed => "vm_edit", :format => :js, "check_#{vm.id}" => "1" }
        expect(controller.send(:flash_errors?)).not_to be_truthy
      end
    end

    describe "#show" do
      let(:ems_kubernetes_container) { FactoryGirl.create(:ems_kubernetes, :name => "test") }
      let(:pdf_options) { controller.instance_variable_get(:@options) }

      context "download pdf file" do
        before :each do
          controller.instance_variable_set(:@table_name, "ems_container")
          set_up_controller_for_show_method(controller, ems_kubernetes_container.id)
          controller.send(:show)
        end

        it "should not contains string 'ManageIQ' in the title of summary report" do
          expect(pdf_options[:title]).not_to include('ManageIQ')
        end

        it "should match proper title of report" do
          expect(pdf_options[:title]).to eq('Container Provider (Kubernetes) "test"')
        end
      end
    end
  end
end

describe EmsInfraController do
  context "#show_link" do
    let(:ems) { double(EmsInfra, id: 1) }
    it "sets relative url" do
      controller.instance_variable_set(:@table_name, "ems_infra")
      link = controller.send(:show_link, ems, :display => "vms")
      expect(link).to eq("/ems_infra/#{ems.id}?display=vms")
    end

    context "#restore_password" do
      it "populates the password from the ems record if params[:restore_password] exists" do
        infra_ems = EmsInfra.new
        allow(infra_ems).to receive(:authentication_password).and_return("default_password")
        edit = {:ems_id => infra_ems.id, :new => {}}
        controller.instance_variable_set(:@edit, edit)
        controller.instance_variable_set(:@ems, infra_ems)
        controller.instance_variable_set(:@_params,
                                         :restore_password => true,
                                         :default_password => "[FILTERED]",
                                         :default_verify   => "[FILTERED]")
        controller.send(:restore_password)
        expect(assigns(:edit)[:new][:default_password]).to eq(infra_ems.authentication_password)
      end
    end
  end

  describe "#show" do
    let(:ems_openstack_infra) { FactoryGirl.create(:ems_openstack_infra, :name => "test") }
    let(:pdf_options) { controller.instance_variable_get(:@options) }

    context "download pdf file" do
      before :each do
        controller.instance_variable_set(:@table_name, "ems_infra")
        set_up_controller_for_show_method(controller, ems_openstack_infra.id)
        controller.send(:show)
      end

      it "should not contains string 'ManageIQ' in the title of summary report" do
        expect(pdf_options[:title]).not_to include('ManageIQ')
      end

      it "should match proper title of report" do
        expect(pdf_options[:title]).to eq('Infrastructure Provider (Openstack) "test"')
      end
    end
  end
end
