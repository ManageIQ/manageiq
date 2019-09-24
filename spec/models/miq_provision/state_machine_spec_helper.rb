module MiqProvision::StateMachineSpecHelper
  include Spec::Support::MiqRequestTaskHelper

  def test_prepare_provision
    call_method
  end

  def test_poll_destination_in_vmdb
    @test_poll_destination_in_vmdb_setup ||= begin
      expect(task).to receive(:requeue_phase).twice { requeue_phase }
      expect(task).to receive(:find_destination_in_vmdb).and_return(nil, nil, vm)
    end
    expect(task.destination).to be_nil

    call_method
  end

  def test_poll_destination_powered_off_in_provider
    expect(task).to receive(:powered_off_in_provider?).and_return(true, false, false, true)
    test_poll_destination_powered_off_in_provider_no_callback
    test_poll_destination_powered_off_in_provider_with_callback_url
  end

  def test_poll_destination_powered_off_in_vmdb
    @test_poll_destination_powered_off_in_vmdb_setup ||= begin
      expect(task).to receive(:requeue_phase) do
        requeue_phase(__method__)
        vm.update(:raw_power_state => "down")
      end
      expect(EmsRefresh).to receive(:queue_refresh)
    end

    skip_post_install_check { call_method }
  end

  def test_post_create_destination
    call_method

    expect(task.destination.description).to eq(options[:vm_description])
    expect(vm.reload.description).to        eq(options[:vm_description])
  end

  def test_post_provision
    call_method
  end

  def test_mark_as_completed
    expect(MiqEvent).to receive(:raise_evm_event)
    expect(task).not_to receive(:call_automate_event)

    call_method
  end

  def test_finish
    call_method
  end

  ### BRANCH STATES
  def test_poll_destination_powered_off_in_provider_with_callback_url
    expect(vm).to receive(:stop)

    call_method
  end

  def test_poll_destination_powered_off_in_provider_no_callback
    @test_poll_destination_powered_off_in_provider_no_callback_setup ||= begin
      expect(task).to receive(:requeue_phase).twice { requeue_phase(__method__) }
    end

    skip_post_install_check { call_method }
  end
end
