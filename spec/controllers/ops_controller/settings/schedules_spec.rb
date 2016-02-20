describe OpsController do
  let(:params) { {} }
  let(:session) { {} }

  include_context "valid session"

  describe "#schedule_form_filter_type_field_changed" do
    before do
      params[:filter_type] = filter_type
      params[:id] = "123"
    end

    context "when the filter_type is 'vm'" do
      let(:vm) { double("Vm", :name => "vmtest") }
      let(:filter_type) { "vm" }

      before do
        allow(Vm).to receive(:find).with(:all, {}).and_return([vm])
        post :schedule_form_filter_type_field_changed, :params => params, :session => session
      end

      it "responds with a filtered vm list" do
        json = JSON.parse(response.body)
        expect(json["filtered_item_list"]).to eq(["vmtest"])
      end
    end

    context "when the filter_type is 'ems'" do
      let(:ext_management_system) { double("ExtManagementSystem", :name => "emstest") }
      let(:filter_type) { "ems" }

      before do
        allow(ExtManagementSystem).to receive(:find).with(:all, {}).and_return([ext_management_system])
        post :schedule_form_filter_type_field_changed, :params => params, :session => session
      end

      it "responds with a filtered ext management system list" do
        json = JSON.parse(response.body)
        expect(json["filtered_item_list"]).to eq(["emstest"])
      end
    end

    context "when the filter_type is 'cluster'" do
      let(:cluster) do
        double(
          "EmsCluster",
          :name                => "clustertest",
          :v_parent_datacenter => "datacenter",
          :v_qualified_desc    => "desc"
        )
      end
      let(:filter_type) { "cluster" }

      before do
        bypass_rescue
        allow(EmsCluster).to receive(:find).with(:all, {}).and_return([cluster])
        post :schedule_form_filter_type_field_changed, :params => params, :session => session
      end

      it "responds with a filtered cluster list" do
        json = JSON.parse(response.body)
        expect(json["filtered_item_list"]).to eq([%w(clustertest__datacenter desc)])
      end
    end

    context "when the filter_type is 'host'" do
      let(:host) { double("Host", :name => "hosttest") }
      let(:filter_type) { "host" }

      before do
        allow(Host).to receive(:find).with(:all, {}).and_return([host])
        post :schedule_form_filter_type_field_changed, :params => params, :session => session
      end

      it "responds with a filtered host list" do
        json = JSON.parse(response.body)
        expect(json["filtered_item_list"]).to eq(["hosttest"])
      end
    end
  end
  context "#build_uri_settings" do
    let(:mocked_filedepot) { double(FileDepotSmb) }
    it "uses params[:log_password] for validation if one exists" do
      controller.instance_variable_set(:@_params,
                                       :log_userid   => "userid",
                                       :log_password => "password2",
                                       :uri_prefix   => "smb",
                                       :uri          => "samba_uri",
                                       :log_protocol => "Samba")
      settings = {:username   => "userid",
                  :password   => "password2",
                  :uri        => "smb://samba_uri",
                  :uri_prefix => "smb"
                 }
      expect(controller.send(:build_uri_settings, :mocked_filedepot)).to include(settings)
    end

    it "uses the stored password for validation if params[:log_password] does not exist" do
      controller.instance_variable_set(:@_params,
                                       :log_userid   => "userid",
                                       :uri_prefix   => "smb",
                                       :uri          => "samba_uri",
                                       :log_protocol => "Samba")
      expect(mocked_filedepot).to receive(:try).with(:authentication_password).and_return('password')
      settings = {:username   => "userid",
                  :password   => "password",
                  :uri        => "smb://samba_uri",
                  :uri_prefix => "smb"
                 }
      expect(controller.send(:build_uri_settings, mocked_filedepot)).to include(settings)
    end
  end
end
