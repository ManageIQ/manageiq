RSpec.describe MiqProvision::PostInstallCallback do
  let(:included_class) do
    Class.new do
      include MiqProvision::PostInstallCallback

      attr_reader :destination, :phase

      def initialize(destination, phase)
        @destination = destination
        @phase       = phase.to_s
      end

      def for_destination; end

      def _log
        @logger ||= Vmdb.logger
      end
    end
  end

  let(:destination) { FactoryBot.build(:vm) }

  ALLOWED_PHASES = [:poll_destination_powered_off_in_provider, :poll_destination_powered_off_in_vmdb].freeze
  BLOCKED_PHASES = [
    :autostart_destination,
    :boot_from_cdrom,
    :boot_from_network,
    :configure_destination,
    :create_destination,
    :create_pxe_configuration_file,
    :create_pxe_configuration_files,
    :customize_destination,
    :delete_pxe_configuration_files,
    :determine_placement,
    :enable_build_mode,
    :finish,
    :mark_as_completed,
    :os_build,
    :poll_clone_complete,
    :poll_destination_in_vmdb,
    :poll_destination_powered_on_in_provider,
    :poll_os_built,
    :poll_system_powered_off_in_foreman,
    :post_create_destination,
    :post_provision,
    :prepare_provision,
    :provision_error,
    :reboot,
    :reset_host_credentials,
    :reset_host_in_vmdb,
    :start_clone_task,
    :start_configuration_task,
    :system_power_off_in_foreman,
    :update_configuration
  ].freeze

  context "#post_install_callback" do
    BLOCKED_PHASES.each do |phase|
      it "should not call power off for #{phase}" do
        expect(destination).not_to receive(:stop)
        included_class.new(destination, phase).post_install_callback
      end
    end

    ALLOWED_PHASES.each do |phase|
      it "should call power off for #{phase}" do
        expect(destination).to receive(:stop)
        included_class.new(destination, phase).post_install_callback
      end
    end
  end
end
