RSpec.describe MiqEnvironment do
  context "with linux platform" do
    before do
      @old_impl = Sys::Platform::IMPL
      silence_warnings { Sys::Platform::IMPL = :linux }
    end

    after do
      silence_warnings { Sys::Platform::IMPL = @old_impl } if @old_impl
    end

    context "Host Info" do
      example "fully_qualified_domain_name" do
        skip if RUBY_PLATFORM.include?("darwin")
        expect(described_class.fully_qualified_domain_name).to eq(`hostname -f`.chomp)
      end

      example "local_ip_address" do
        expect(described_class.local_ip_address).to be_in(Socket.ip_address_list.map(&:ip_address))
      end

      context "multiple private addresses" do
        it "always returns the same address" do
          allow(Socket).to receive(:ip_address_list).and_return([Addrinfo.ip("192.168.1.10"), Addrinfo.ip("10.1.2.3")])
          expect(described_class.local_ip_address).to eq("10.1.2.3")
          allow(Socket).to receive(:ip_address_list).and_return([Addrinfo.ip("10.1.2.3"), Addrinfo.ip("192.168.1.10")])
          expect(described_class.local_ip_address).to eq("10.1.2.3")
        end
      end
    end

    context "Command" do
      context ".supports_nohup_and_backgrounding?" do
        it "should run once and cache the result" do
          expect(MiqEnvironment::Command).to receive(:is_appliance?).once.and_return(false)
          assert_same_result_every_time(:supports_nohup_and_backgrounding?, false)
        end
      end

      context ".is_production?" do
        it "when Rails is not defined" do
          hide_const('Rails')
          expect { Rails }.to raise_error(NameError)
          assert_same_result_every_time(:is_production?, true)
        end

        it "when Rails is production" do
          expect(Rails.env).to receive(:production?).twice.and_return(true)
          assert_same_result_every_time(:is_production?, true)
        end

        it "when Rails is not production" do
          assert_same_result_every_time(:is_production?, false)
        end
      end

      context "production build questions" do
        let(:token_file) { "/run/secrets/kubernetes.io/serviceaccount/token" }
        let(:ca_file)    { "/run/secrets/kubernetes.io/serviceaccount/ca.crt" }

        def container_conditions
          stub_const("ENV", ENV.to_h.merge("CONTAINER" => "true"))
        end

        def podified_conditions
          allow(File).to receive(:exist?).with(token_file).and_return(true)
          allow(File).to receive(:exist?).with(ca_file).and_return(true)
          container_conditions
        end

        def appliance_conditions
          stub_const("ENV", ENV.to_h.merge("APPLIANCE" => "true"))
        end

        describe ".is_container?" do
          it "when the conditions are not met" do
            assert_same_result_every_time(:is_container?, false)
          end

          it "when the conditions are met" do
            container_conditions
            assert_same_result_every_time(:is_container?, true)
          end
        end

        describe ".is_podified?" do
          it "when the conditions are not met" do
            assert_same_result_every_time(:is_podified?, false)
          end

          it "when the conditions are met" do
            podified_conditions
            assert_same_result_every_time(:is_podified?, true)
          end
        end

        describe ".is_appliance?" do
          it "when the conditions are not met" do
            assert_same_result_every_time(:is_appliance?, false)
          end

          it "when the conditions are met" do
            appliance_conditions
            assert_same_result_every_time(:is_appliance?, true)
          end
        end

        describe ".is_production_build?" do
          it "when the conditions are not met" do
            assert_same_result_every_time(:is_production_build?, false)
          end

          it "when the appliance conditions are met" do
            appliance_conditions
            assert_same_result_every_time(:is_production_build?, true)
          end

          it "when the container conditions are met" do
            container_conditions
            assert_same_result_every_time(:is_production_build?, true)
          end

          it "when the podified conditions are met" do
            podified_conditions
            assert_same_result_every_time(:is_production_build?, true)
          end
        end

        context ".supports_systemd?" do
          it "returns false when container conditions are met" do
            container_conditions
            assert_same_result_every_time(:supports_systemd?, false)
          end

          it "returns true when appliance conditions are met" do
            appliance_conditions
            expect(MiqEnvironment::Command).to receive(:supports_command?).with("systemctl").and_return(true)
            assert_same_result_every_time(:supports_systemd?, true)
          end
        end
      end
    end
  end

  def assert_same_result_every_time(method, expected)
    2.times { expect(MiqEnvironment::Command.send(method)).to eq(expected) }
  end
end
