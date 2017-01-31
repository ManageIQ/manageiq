RSpec.describe "Snapshots API" do
  describe "as a subcollection of VMs" do
    describe "GET /api/vms/:c_id/snapshots" do
      it "can list the snapshots of a VM" do
        api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :read, :get))
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)
        _other_snapshot = FactoryGirl.create(:snapshot)

        run_get("#{vms_url(vm.id)}/snapshots")

        expected = {
          "count"     => 2,
          "name"      => "snapshots",
          "subcount"  => 1,
          "resources" => [
            {"href" => a_string_matching("#{vms_url(vm.id)}/snapshots/#{snapshot.id}")}
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not list snapshots unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)
        FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_get("#{vms_url(vm.id)}/snapshots")

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/vms/:c_id/snapshots/:s_id" do
    it "can show a VM's snapshot" do
      api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :read, :get))
      vm = FactoryGirl.create(:vm_vmware)
      create_time = Time.zone.parse("2017-01-11T00:00:00Z")
      snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm, :create_time => create_time)

      run_get("#{vms_url(vm.id)}/snapshots/#{snapshot.id}")

      expected = {
        "create_time"       => create_time.iso8601,
        "href"              => a_string_matching("#{vms_url(vm.id)}/snapshots/#{snapshot.id}"),
        "id"                => snapshot.id,
        "vm_or_template_id" => vm.id
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "will not show a snapshot unless authorized" do
      api_basic_authorize
      vm = FactoryGirl.create(:vm_vmware)
      snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

      run_get("#{vms_url(vm.id)}/snapshots/#{snapshot.id}")

      expect(response).to have_http_status(:forbidden)
    end

    describe "POST /api/vms/:c_id/snapshots" do
      it "can queue the creation of a snapshot" do
        api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :create))
        ems = FactoryGirl.create(:ext_management_system)
        host = FactoryGirl.create(:host, :ext_management_system => ems)
        vm = FactoryGirl.create(:vm_vmware, :name => "Alice's VM", :host => host, :ext_management_system => ems)

        run_post("#{vms_url(vm.id)}/snapshots", :name => "Alice's snapshot")

        expected = {
          "results" => [
            a_hash_including(
              "success"   => true,
              "message"   => "Creating snapshot Alice's snapshot for Vm id:#{vm.id} name:'Alice's VM'",
              "task_id"   => anything,
              "task_href" => a_string_matching(tasks_url)
            )
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "renders a failed action response if snapshotting is not supported" do
        api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :create))
        vm = FactoryGirl.create(:vm_vmware)

        run_post("#{vms_url(vm.id)}/snapshots", :name => "Alice's snapsnot")

        expected = {
          "results" => [
            a_hash_including(
              "success" => false,
              "message" => "The VM is not connected to a Host"
            )
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "renders a failed action response if a name is not provided" do
        api_basic_authorize(subcollection_action_identifier(:vms, :snapshots, :create))
        ems = FactoryGirl.create(:ext_management_system)
        host = FactoryGirl.create(:host, :ext_management_system => ems)
        vm = FactoryGirl.create(:vm_vmware, :name => "Alice's VM", :host => host, :ext_management_system => ems)

        run_post("#{vms_url(vm.id)}/snapshots", :description => "Alice's snapshot")

        expected = {
          "results" => [
            a_hash_including(
              "success" => false,
              "message" => "Must specify a name for the snapshot"
            )
          ]
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not create a snapshot unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)

        run_post("#{vms_url(vm.id)}/snapshots", :description => "Alice's snapshot")

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/vms/:c_id/snapshots/:s_id with delete action" do
      it "can queue a snapshot for deletion" do
        api_basic_authorize(action_identifier(:snapshots, :delete, :subresource_actions, :delete))
        ems = FactoryGirl.create(:ext_management_system)
        host = FactoryGirl.create(:host, :ext_management_system => ems)
        vm = FactoryGirl.create(:vm_vmware, :name => "Alice's VM", :host => host, :ext_management_system => ems)
        snapshot = FactoryGirl.create(:snapshot, :name => "Alice's snapshot", :vm_or_template => vm)

        run_post("#{vms_url(vm.id)}/snapshots/#{snapshot.id}", :action => "delete")

        expected = {
          "message"   => "Deleting snapshot Alice's snapshot for Vm id:#{vm.id} name:'Alice's VM'",
          "success"   => true,
          "task_href" => a_string_matching(tasks_url),
          "task_id"   => anything
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "renders a failed action response if deleting is not supported" do
        api_basic_authorize(action_identifier(:snapshots, :delete, :subresource_actions, :post))
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_post("#{vms_url(vm.id)}/snapshots/#{snapshot.id}", :action => "delete")

        expected = {
          "success" => false,
          "message" => "The VM is not connected to a Host"
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not delete a snapshot unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_post("#{vms_url(vm.id)}/snapshots/#{snapshot.id}", :action => "delete")

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /api/vms/:c_id/snapshots with delete action" do
      it "can queue multiple snapshots for deletion" do
        api_basic_authorize(action_identifier(:snapshots, :delete, :subresource_actions, :delete))
        ems = FactoryGirl.create(:ext_management_system)
        host = FactoryGirl.create(:host, :ext_management_system => ems)
        vm = FactoryGirl.create(:vm_vmware, :name => "Alice and Bob's VM", :host => host, :ext_management_system => ems)
        snapshot1 = FactoryGirl.create(:snapshot, :name => "Alice's snapshot", :vm_or_template => vm)
        snapshot2 = FactoryGirl.create(:snapshot, :name => "Bob's snapshot", :vm_or_template => vm)

        run_post(
          "#{vms_url(vm.id)}/snapshots",
          :action    => "delete",
          :resources => [
            {:href => "#{vms_url(vm.id)}/snapshots/#{snapshot1.id}"},
            {:href => "#{vms_url(vm.id)}/snapshots/#{snapshot2.id}"}
          ]
        )

        expected = {
          "results" => a_collection_containing_exactly(
            a_hash_including(
              "message"   => "Deleting snapshot Alice's snapshot for Vm id:#{vm.id} name:'Alice and Bob's VM'",
              "success"   => true,
              "task_href" => a_string_matching(tasks_url),
              "task_id"   => anything
            ),
            a_hash_including(
              "message"   => "Deleting snapshot Bob's snapshot for Vm id:#{vm.id} name:'Alice and Bob's VM'",
              "success"   => true,
              "task_href" => a_string_matching(tasks_url),
              "task_id"   => anything
            )
          )
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "DELETE /api/vms/:c_id/snapshots/:s_id" do
      it "can delete a snapshot" do
        api_basic_authorize(action_identifier(:snapshots, :delete, :subresource_actions, :delete))
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_delete("#{vms_url(vm.id)}/snapshots/#{snapshot.id}")

        expect(response).to have_http_status(:no_content)
      end

      it "will not delete a snapshot unless authorized" do
        api_basic_authorize
        vm = FactoryGirl.create(:vm_vmware)
        snapshot = FactoryGirl.create(:snapshot, :vm_or_template => vm)

        run_delete("#{vms_url(vm.id)}/snapshots/#{snapshot.id}")

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
