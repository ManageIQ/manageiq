#
# Rest API Request Tests - Services specs
#
# - Edit service                /api/services/:id     action "edit"
# - Edit service via PUT        /api/services/:id     PUT
# - Edit service via PATCH      /api/services/:id     PATCH
# - Edit multiple services      /api/services         action "edit"
#
# - Delete service              /api/services/:id     DELETE
# - Delete multiple services    /api/services         action "delete"
#
# - Retire service now          /api/services/:id     action "retire"
# - Retire service future       /api/services/:id     action "retire"
# - Retire multiple services    /api/services         action "retire"
#
describe ApiController do
  let(:svc)  { FactoryGirl.create(:service, :name => "svc",  :description => "svc description")  }
  let(:svc1) { FactoryGirl.create(:service, :name => "svc1", :description => "svc1 description") }
  let(:svc2) { FactoryGirl.create(:service, :name => "svc2", :description => "svc2 description") }

  describe "Services edit" do
    it "rejects requests without appropriate role" do
      api_basic_authorize

      run_post(services_url(svc.id), gen_request(:edit, "name" => "sample service"))

      expect_request_forbidden
    end

    it "supports edits of single resource" do
      api_basic_authorize collection_action_identifier(:services, :edit)

      run_post(services_url(svc.id), gen_request(:edit, "name" => "updated svc1"))

      expect_single_resource_query("id" => svc.id, "href" => services_url(svc.id), "name" => "updated svc1")
      expect(svc.reload.name).to eq("updated svc1")
    end

    it "supports edits of single resource via PUT" do
      api_basic_authorize collection_action_identifier(:services, :edit)

      run_put(services_url(svc.id), "name" => "updated svc1")

      expect_single_resource_query("id" => svc.id, "href" => services_url(svc.id), "name" => "updated svc1")
      expect(svc.reload.name).to eq("updated svc1")
    end

    it "supports edits of single resource via PATCH" do
      api_basic_authorize collection_action_identifier(:services, :edit)

      run_patch(services_url(svc.id), [{"action" => "edit",   "path" => "name",        "value" => "updated svc1"},
                                       {"action" => "remove", "path" => "description"},
                                       {"action" => "add",    "path" => "display",     "value" => true}])

      expect_single_resource_query("id" => svc.id, "name" => "updated svc1", "display" => true)
      expect(svc.reload.name).to eq("updated svc1")
      expect(svc.description).to be_nil
      expect(svc.display).to be_truthy
    end

    it "supports edits of multiple resources" do
      api_basic_authorize collection_action_identifier(:services, :edit)

      run_post(services_url, gen_request(:edit,
                                         [{"href" => services_url(svc1.id), "name" => "updated svc1"},
                                          {"href" => services_url(svc2.id), "name" => "updated svc2"}]))

      expect_request_success
      expect_results_to_match_hash("results",
                                   [{"id" => svc1.id, "name" => "updated svc1"},
                                    {"id" => svc2.id, "name" => "updated svc2"}])
      expect(svc1.reload.name).to eq("updated svc1")
      expect(svc2.reload.name).to eq("updated svc2")
    end
  end

  describe "Services delete" do
    it "rejects POST delete requests without appropriate role" do
      api_basic_authorize

      run_post(services_url, gen_request(:delete, "href" => services_url(100)))

      expect_request_forbidden
    end

    it "rejects DELETE requests without appropriate role" do
      api_basic_authorize

      run_delete(services_url(100))

      expect_request_forbidden
    end

    it "rejects requests for invalid resources" do
      api_basic_authorize collection_action_identifier(:services, :delete)

      run_delete(services_url(999_999))

      expect_resource_not_found
    end

    it "supports single resource deletes" do
      api_basic_authorize collection_action_identifier(:services, :delete)

      run_delete(services_url(svc.id))

      expect_request_success_with_no_content
      expect { svc.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "supports multiple resource deletes" do
      api_basic_authorize collection_action_identifier(:services, :delete)

      run_post(services_url, gen_request(:delete,
                                         [{"href" => services_url(svc1.id)},
                                          {"href" => services_url(svc2.id)}]))
      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results",
                                               [services_url(svc1.id), services_url(svc2.id)])
      expect { svc1.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { svc2.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Services retirement" do
    def format_retirement_date(time)
      time.strftime("%Y-%m-%d")
    end

    it "rejects requests without appropriate role" do
      api_basic_authorize

      run_post(services_url(100), gen_request(:retire))

      expect_request_forbidden
    end

    it "rejects multiple requests without appropriate role" do
      api_basic_authorize

      run_post(services_url, gen_request(:retire, [{"href" => services_url(1)}, {"href" => services_url(2)}]))

      expect_request_forbidden
    end

    it "supports single service retirement now" do
      api_basic_authorize collection_action_identifier(:services, :retire)

      expect(MiqEvent).to receive(:raise_evm_event).once

      run_post(services_url(svc.id), gen_request(:retire))

      expect_single_resource_query("id" => svc.id, "href" => services_url(svc.id))
    end

    it "supports single service retirement in future" do
      api_basic_authorize collection_action_identifier(:services, :retire)

      ret_date = format_retirement_date(Time.now + 5.days)

      run_post(services_url(svc.id), gen_request(:retire, "date" => ret_date, "warn" => 2))

      expect_single_resource_query("id" => svc.id, "retires_on" => ret_date, "retirement_warn" => 2)
      expect(format_retirement_date(svc.reload.retires_on)).to eq(ret_date)
      expect(svc.retirement_warn).to eq(2)
    end

    it "supports multiple service retirement now" do
      api_basic_authorize collection_action_identifier(:services, :retire)

      expect(MiqEvent).to receive(:raise_evm_event).twice

      run_post(services_url, gen_request(:retire,
                                         [{"href" => services_url(svc1.id)},
                                          {"href" => services_url(svc2.id)}]))

      expect_results_to_match_hash("results", [{"id" => svc1.id}, {"id" => svc2.id}])
    end

    it "supports multiple service retirement in future" do
      api_basic_authorize collection_action_identifier(:services, :retire)

      ret_date = format_retirement_date(Time.now + 2.days)

      run_post(services_url, gen_request(:retire,
                                         [{"href" => services_url(svc1.id), "date" => ret_date, "warn" => 3},
                                          {"href" => services_url(svc2.id), "date" => ret_date, "warn" => 5}]))

      expect_results_to_match_hash("results",
                                   [{"id" => svc1.id, "retires_on" => ret_date, "retirement_warn" => 3},
                                    {"id" => svc2.id, "retires_on" => ret_date, "retirement_warn" => 5}])
      expect(format_retirement_date(svc1.reload.retires_on)).to eq(ret_date)
      expect(svc1.retirement_warn).to eq(3)
      expect(format_retirement_date(svc2.reload.retires_on)).to eq(ret_date)
      expect(svc2.retirement_warn).to eq(5)
    end
  end
end
