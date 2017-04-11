describe ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcherMixin do
  let(:test_class) do
    Class.new do
      def initialize(ems = nil)
        @ems = ems if ems
      end
    end.include(described_class)
  end
  let(:ems) { FactoryGirl.create(:ems_kubernetes) }

  describe '#extract_event_data' do
    context 'given container event (Pod event with fieldPath)' do
      let(:kubernetes_event) do
        {
          'kind'           => 'Event',
          'apiVersion'     => 'v1',
          'metadata'       => {
            'name'              => 'heapster-aas69.14636726235d5e81',
            'namespace'         => 'openshift-infra',
            'selfLink'          => '/api/v1/namespaces/openshift-infra/events/heapster-aas69.14636726235d5e81',
            'uid'               => 'fa735ca9-4f7d-11e6-b177-525400c7c086',
            'resourceVersion'   => '1329090',
            'creationTimestamp' => '2016-07-21T20:01:57Z',
            'deletionTimestamp' => '2016-07-21T22:01:57Z'
          },
          'involvedObject' => {
            'kind'            => 'Pod',
            'namespace'       => 'openshift-infra',
            'name'            => 'heapster-aas69',
            'uid'             => '72d3098a-4f6a-11e6-b177-525400c7c086',
            'apiVersion'      => 'v1',
            'resourceVersion' => '1323182',
            'fieldPath'       => 'spec.containers{heapster}'
          },
          'reason'         => 'Killing',
          'message'        => 'Killing container with docker id 18a563fdb87c: failed to call event handler: '\
                              'Error executing in Docker Container: -1',
          'source'         => {
            'component' => 'kubelet',
            'host'      => 'vm-test-03.example.com'
          },
          'firstTimestamp' => '2016-07-21T20:01:56Z',
          'lastTimestamp'  => '2016-07-21T20:01:56Z',
          'count'          => 1,
          'type'           => 'Normal'
        }
      end

      it 'extracts CONTAINER_KILLING data' do
        expected_data = {
          :timestamp            => '2016-07-21T20:01:56Z',
          :kind                 => 'Pod',
          :name                 => 'heapster-aas69',
          :namespace            => 'openshift-infra',
          :reason               => 'Killing',
          :message              => 'Killing container with docker id 18a563fdb87c: failed to call event handler: '\
                                   'Error executing in Docker Container: -1',
          :uid                  => '72d3098a-4f6a-11e6-b177-525400c7c086',
          :fieldpath            => 'spec.containers{heapster}',
          :container_name       => 'heapster',
          :container_group_name => 'heapster-aas69',
          :container_namespace  => 'openshift-infra',
          :event_type           => 'CONTAINER_KILLING'
        }
        event = RecursiveOpenStruct.new(:object => kubernetes_event)
        expect(test_class.new.extract_event_data(event)).to eq(expected_data)
      end
    end

    context 'given pod event (no fieldPath)' do
      let(:kubernetes_event) do
        {
          'metadata'       => {
            'name'              => 'ruby-ex-4-6o0b5.146481d987d53341',
            'namespace'         => 'proj',
            'selfLink'          => '/api/v1/namespaces/proj/events/ruby-ex-4-6o0b5.146481d987d53341',
            'uid'               => 'b10955d1-5251-11e6-8564-525400c7c086',
            'resourceVersion'   => '1358590',
            'creationTimestamp' => '2016-07-25T10:22:29Z',
            'deletionTimestamp' => '2016-07-25T13:04:06Z'
          },
          'involvedObject' => {
            'kind'            => 'Pod',
            'namespace'       => 'proj',
            'name'            => 'ruby-ex-4-6o0b5',
            'uid'             => 'e12e8bf2-4d8f-11e6-bcf3-525400c7c086',
            'apiVersion'      => 'v1',
            'resourceVersion' => '1342618'
          },
          'reason'         => 'FailedSync',
          'message'        => 'Error syncing pod, skipping: API error (500): Unknown device '\
                              'bd312cc17e3e1554ca5cb15468232c0d0cc51b0c25bf6fb487481237dab5d453\n',
          'source'         => {
            'component' => 'kubelet',
            'host'      => 'vm-test-02.example.com'
          },
          'firstTimestamp' => '2016-07-25T10:22:29Z',
          'lastTimestamp'  => '2016-07-25T11:04:06Z',
          'count'          => 227,
          'type'           => 'Warning'
        }
      end
    end

    context 'given replicator event' do
      let(:kubernetes_event) do
        {
          'metadata'       => {
            'name'              => 'mysql-1.146486622e01d244',
            'namespace'         => 'proj',
            'selfLink'          => '/api/v1/namespaces/proj/events/mysql-1.146486622e01d244',
            'uid'               => '4c513e6d-525d-11e6-8564-525400c7c086',
            'resourceVersion'   => '1360577',
            'creationTimestamp' => '2016-07-25T11:45:34Z',
            'deletionTimestamp' => '2016-07-25T13:45:34Z'
          },
          'involvedObject' => {
            'kind'            => 'ReplicationController',
            'namespace'       => 'proj',
            'name'            => 'mysql-1',
            'uid'             => '7599d451-4c1c-11e6-89dd-525400c7c086',
            'apiVersion'      => 'v1',
            'resourceVersion' => '1360571'
          },
          'reason'         => 'SuccessfulCreate',
          'message'        => 'Created pod: mysql-1-i4b54',
          'source'         => {
            'component' => 'replication-controller'
          },
          'firstTimestamp' => '2016-07-25T11:45:34Z',
          'lastTimestamp'  => '2016-07-25T11:45:34Z',
          'count'          => 1,
          'type'           => 'Normal'
        }
      end

      it 'extracts REPLICATOR_SUCCESSFULCREATE event data' do
        expected_data = {
          :timestamp                 => '2016-07-25T11:45:34Z',
          :kind                      => 'ReplicationController',
          :name                      => 'mysql-1',
          :namespace                 => 'proj',
          :reason                    => 'SuccessfulCreate',
          :message                   => 'Created pod: mysql-1-i4b54',
          :uid                       => '7599d451-4c1c-11e6-89dd-525400c7c086',
          :container_replicator_name => 'mysql-1',
          :container_namespace       => 'proj',
          :event_type                => 'REPLICATOR_SUCCESSFULCREATE'
        }
        event = RecursiveOpenStruct.new(:object => kubernetes_event)
        expect(test_class.new.extract_event_data(event)).to eq(expected_data)
      end
    end

    context 'given node event' do
      let(:kubernetes_event) do
        {
          'metadata'       => {
            'name'              => 'vm-test-03.example.com.146481d4a19edff4',
            'namespace'         => 'default',
            'selfLink'          => '/api/v1/namespaces/default/events/vm-test-03.example.com.146481d4a19edff4',
            'uid'               => 'a4b92ae1-5251-11e6-8564-525400c7c086',
            'resourceVersion'   => '1356588',
            'creationTimestamp' => '2016-07-25T10:22:09Z',
            'deletionTimestamp' => '2016-07-25T12:22:09Z'
          },
          'involvedObject' => {
            'kind' => 'Node',
            'name' => 'vm-test-03.example.com',
            # Actually saw 'uid' => 'vm-test-03.example.com' but this is what we will get once
            # https://github.com/kubernetes/kubernetes/issues/29289 gets fixed.
            'uid'  => 'd30a880d-dfa7-11e5-af89-525400c7c086'
          },
          'reason'         => 'Rebooted',
          'message'        => 'Node vm-test-03.example.com has been rebooted, boot id: '\
                              'c75d2b66-6d5b-49e0-b906-1d8abaf3e73b',
          'source'         => {
            'component' => 'kubelet',
            'host'      => 'vm-test-03.example.com'
          },
          'firstTimestamp' => '2016-07-25T10:22:08Z',
          'lastTimestamp'  => '2016-07-25T10:22:08Z',
          'count'          => 1,
          'type'           => 'Warning'
        }
      end

      let(:expected_data) do
        {
          :timestamp           => '2016-07-25T10:22:08Z',
          :kind                => 'Node',
          :name                => 'vm-test-03.example.com',
          :namespace           => nil,
          :reason              => 'Rebooted',
          :message             => 'Node vm-test-03.example.com has been rebooted, boot id: '\
                                  'c75d2b66-6d5b-49e0-b906-1d8abaf3e73b',
          :uid                 => 'd30a880d-dfa7-11e5-af89-525400c7c086',
          :container_node_name => 'vm-test-03.example.com',
          :event_type          => 'NODE_REBOOTED'
        }
      end

      it 'given good uid extracts NODE_REBOOTED event data' do
        event = RecursiveOpenStruct.new(:object => kubernetes_event)
        expect(test_class.new.extract_event_data(event)).to eq(expected_data)
      end

      # Remove when we no longer support kubernetes with bug
      # https://github.com/kubernetes/kubernetes/issues/29289
      context 'given useless/missing uid' do
        # We've seen events with both missing uid and uid == name.
        let(:bad_uid_event) do
          RecursiveOpenStruct.new(:object => kubernetes_event.merge(
            'involvedObject' => {
              'kind' => 'Node',
              'name' => 'vm-test-03.example.com',
              'uid'  => 'vm-test-03.example.com'
            }
          ))
        end

        let(:missing_uid_event) do
          RecursiveOpenStruct.new(:object => kubernetes_event.merge(
            'involvedObject' => {
              'kind' => 'Node',
              'name' => 'vm-test-03.example.com'
            }
          ))
        end

        it 'without matching node returns nil uid' do
          expect(test_class.new(ems).extract_event_data(bad_uid_event)[:uid]).to eq(nil)
          expect(test_class.new(ems).extract_event_data(missing_uid_event)[:uid]).to eq(nil)
        end

        it 'with matching node takes its uid' do
          node = FactoryGirl.create(:container_node, :name => 'vm-test-03.example.com')
          node.ext_management_system = ems
          node.ems_ref = 'd30a880d-dfa7-11e5-af89-525400c7c086'
          node.save

          expect(test_class.new(ems).extract_event_data(bad_uid_event)).to eq(expected_data)
          expect(test_class.new(ems).extract_event_data(missing_uid_event)).to eq(expected_data)
        end
      end
    end
  end
end
