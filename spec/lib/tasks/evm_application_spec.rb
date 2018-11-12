require "tempfile"
require "fileutils"
require Rails.root.join("lib", "tasks", "evm_application")

describe EvmApplication do
  context ".server_state" do
    it "with a valid status" do
      EvmSpecHelper.create_guid_miq_server_zone

      expect(EvmApplication.server_state).to eq("started")
    end

    it "without a database connection" do
      allow(MiqServer).to receive(:my_server).and_raise("`initialize': could not connect to server: Connection refused (PGError)")

      expect(EvmApplication.server_state).to eq(:no_db)
    end
  end

  describe ".servers_status" do
    let(:local_zone)  { FactoryGirl.create(:zone, :name => 'A Zone') }
    let(:local)    { EvmSpecHelper.local_miq_server(:started_on => 1.hour.ago, :last_heartbeat => 2.days.ago, :zone => local_zone) }
    let(:remote)   { EvmSpecHelper.remote_miq_server(:is_master => true, :last_heartbeat => nil) }
    let!(:ui)      { FactoryGirl.create(:miq_ui_worker, :miq_server => local, :pid => 80_000) }
    let!(:generic) { FactoryGirl.create(:miq_generic_worker, :miq_server => remote, :pid => 7_000) }
    let!(:refresh) { FactoryGirl.create(:miq_ems_refresh_worker, :miq_server => remote) }

    it "displays server status for local and remote servers" do
      expect(described_class.servers_status([local, remote])).to eq(
        [
          {
            "Region"    => local.region_number,
            "Zone"      => local.zone.name,
            "Server"    => local.name,
            "Status"    => "started",
            "PID"       => nil,
            "SPID"      => nil,
            "Workers"   => 1,
            "Version"   => "9.9.9.9",
            "Started"   => local.started_on.strftime("%H:%M:%S%Z"),
            "Heartbeat" => local.last_heartbeat.strftime("%Y-%m-%d"),
            "MB Usage"  => "",
            "Roles"     => "",
          },
          {
            "Region"    => remote.region_number,
            "Zone"      => remote.zone.name,
            "Server"    => remote.name + "*",
            "Status"    => "started",
            "PID"       => nil,
            "SPID"      => nil,
            "Workers"   => 2,
            "Version"   => "9.9.9.9",
            "Started"   => remote.started_on.strftime("%H:%M:%S%Z"),
            "Heartbeat" => "",
            "MB Usage"  => "",
            "Roles"     => "",
          },
        ]
      )
    end
  end

  describe ".worker_status" do
    let(:local_zone)  { FactoryGirl.create(:zone, :name => 'A Zone') }
    let(:local)    { EvmSpecHelper.local_miq_server(:started_on => 1.hour.ago, :last_heartbeat => 2.days.ago, :zone => local_zone) }
    let(:remote)   { EvmSpecHelper.remote_miq_server(:is_master => true, :last_heartbeat => nil) }
    let!(:ui)      { FactoryGirl.create(:miq_ui_worker, :miq_server => local, :pid => 80_000) }
    let!(:generic) { FactoryGirl.create(:miq_generic_worker, :miq_server => remote, :pid => 7_000) }
    let!(:refresh) { FactoryGirl.create(:miq_ems_refresh_worker, :miq_server => remote) }

    it "displays worker status for local and remote server" do
      expect(described_class.workers_status([local, remote])).to eq(
        [
          {
            "Region"    => local.region_number,
            "Zone"      => local.zone.name,
            "Type"      => "Ui",
            "Status"    => "ready",
            "PID"       => ui.pid,
            "SPID"      => nil,
            "Server"    => local.name,
            "Queue"     => "",
            "Started"   => "",
            "Heartbeat" => "",
            "MB Usage"  => "",
          },
          {
            "Region"    => remote.region_number,
            "Zone"      => remote.zone.name,
            "Type"      => "Base::Refresh",
            "Status"    => "ready",
            "PID"       => refresh.pid,
            "SPID"      => nil,
            "Server"    => remote.name,
            "Queue"     => "",
            "Started"   => "",
            "Heartbeat" => "",
            "MB Usage"  => "",
          },
          {
            "Region"    => remote.region_number,
            "Zone"      => remote.zone.name,
            "Type"      => "Generic",
            "Status"    => "ready",
            "PID"       => generic.pid,
            "SPID"      => nil,
            "Server"    => remote.name,
            "Queue"     => "",
            "Started"   => "",
            "Heartbeat" => "",
            "MB Usage"  => "",
          },
        ]
      )
    end
  end

  describe ".status" do
    def header(col, adjust = :rjust)
      hdr = col == :WID ? "ID" : col.to_s # edge case
      hdr.gsub("_", " ").send(adjust, send("#{col.downcase}_padding"))
    end

    def line_for(col)
      "-" * send("#{col.downcase}_padding")
    end

    def pad(val, col, adjust = :rjust)
      val.to_s.send(adjust, send("#{col.downcase}_padding"))
    end

    let(:local_zone)  { FactoryGirl.create(:zone, :name => 'A Zone') }
    let(:local)    { EvmSpecHelper.local_miq_server(:started_on => 1.hour.ago, :last_heartbeat => 2.days.ago, :zone => local_zone) }
    let(:remote)   { EvmSpecHelper.remote_miq_server(:is_master => true, :last_heartbeat => nil) }
    let(:rgn)      { local.region_number }
    let!(:ui)      { FactoryGirl.create(:miq_ui_worker, :miq_server => local, :pid => 80_000) }
    let!(:generic) { FactoryGirl.create(:miq_generic_worker, :miq_server => remote, :pid => 7_000) }
    let!(:refresh) { FactoryGirl.create(:miq_ems_refresh_worker, :miq_server => remote) }

    let(:local_started_on)  { local.started_on.strftime("%H:%M:%S%Z") }
    let(:local_heartbeat)   { local.last_heartbeat.strftime("%Y-%m-%d") }

    let(:pid_padding)       { ["PID", ui.pid.to_s, generic.pid.to_s].map(&:size).max }
    let(:zone_padding)      { local.zone.name.to_s.size }
    let(:started_padding)   { ["Started", local_started_on].map(&:size).max }
    let(:heartbeat_padding) { ["Heartbeat", local_heartbeat].map(&:size).max }
    let(:region_padding)    { 6 }

    context "for just the local server" do
      it "displays server status for the local server and it's workers" do

        expected_output = <<~SERVER_INFO
          Checking EVM status...
           #{header(:Region)  } | #{header(:Zone, :ljust)} | Server                   | Status  | PID | SPID | Workers | Version | #{header(:Started, :ljust)  } | #{header(:Heartbeat, :ljust)  } | MB Usage | Roles
          -#{line_for(:Region)}-+-#{line_for(:Zone)      }-+--------------------------+---------+-----+------+---------+---------+-#{line_for(:Started)        }-+-#{line_for(:Heartbeat)        }-+----------+-------
           #{pad(rgn, :Region)} | #{local.zone.name      } | #{      local.name     } | started |     |      |       1 | 9.9.9.9 | #{local_started_on          } | #{local_heartbeat             } |          |

          * marks a master appliance

           #{header(:Region)  } | #{header(:Zone, :ljust)} | Type | Status | #{header(:PID)         } | SPID | Server                   | Queue | Started | Heartbeat | MB Usage
          -#{line_for(:Region)}-+-#{line_for(:Zone)      }-+------+--------+-#{line_for(:PID)       }-+------+--------------------------+-------+---------+-----------+----------
           #{pad(rgn, :Region)} | #{local.zone.name      } | Ui   | ready  | #{pad(ui.pid, :PID)    } |      | #{      local.name     } |       |         |           |
        SERVER_INFO

      expect { EvmApplication.status }.to output(expected_output).to_stdout
      end
    end

    context "with remote servers" do
      let(:remote_started_on) { remote.started_on.strftime("%H:%M:%S%Z") }

      let(:pid_padding)       { MiqWorker.all.pluck(:pid).map { |pid| pid.to_s.size }.unshift(3).max }
      let(:zone_padding)      { ["Zone", local.zone.name.to_s, remote.zone.name.to_s].map(&:size).max }
      let(:started_padding)   { ["Started", remote_started_on, local_started_on].map(&:size).max }

      it "displays server status for the all servers and workers" do
        expected_output = <<~SERVER_INFO
          Checking EVM status...
           #{header(:Zone, :ljust)               } | Server                    | Workers | #{header(:Started, :ljust)  } | #{header(:Heartbeat, :ljust).rstrip}
          -#{line_for(:Zone)                     }-+---------------------------+---------+-#{line_for(:Started)        }-+-#{line_for(:Heartbeat)}-
           #{pad(local.zone.name, :Zone, :ljust) } | #{      local.name     }  |       1 | #{local_started_on          } | #{local_heartbeat}
           #{pad(remote.zone.name, :Zone, :ljust)} | #{     remote.name     }* |       2 | #{remote_started_on         } |

          For all rows: Region=#{rgn}, Status=started, Version=9.9.9.9
          * marks a master appliance

           #{header(:Zone, :ljust)               } | Type          | #{header(:PID)          } | Server
          -#{line_for(:Zone)                     }-+---------------+-#{line_for(:PID)        }-+--------------------------
           #{pad(local.zone.name, :Zone, :ljust) } | Ui            | #{pad(ui.pid, :PID)     } | #{      local.name     }
           #{pad(remote.zone.name, :Zone, :ljust)} | Base::Refresh | #{pad(refresh.pid, :PID)} | #{     remote.name     }
           #{pad(remote.zone.name, :Zone, :ljust)} | Generic       | #{pad(generic.pid, :PID)} | #{     remote.name     }

          For all rows: Region=#{rgn}, Status=ready
        SERVER_INFO

        expect { EvmApplication.status(true) }.to output(expected_output).to_stdout
      end
    end
  end

  context ".queue_status" do
    it "calculates oldest and counts" do
      tgt_time = 2.hours.ago
      zone = FactoryGirl.create(:zone)
      MiqQueue.put(:zone => zone.name, :class_name => "X", :method_name => "x", :created_on => 1.hour.ago)
      MiqQueue.put(:zone => zone.name, :class_name => "X", :method_name => "x", :created_on => tgt_time)
      MiqQueue.put(:zone        => zone.name,
                   :class_name  => "X",
                   :method_name => "x",
                   :created_on  => 5.hours.ago,
                   :deliver_on  => 1.hour.from_now)
      expect(described_class.queue_status).to eq(
        [
          {
            "Zone"   => zone.name,
            "Queue"  => "generic",
            "Role"   => nil,
            "method" => "X.x",
            "oldest" => tgt_time.strftime("%Y-%m-%d"),
            "count"  => 3,
          }
        ]
      )
    end

    it "groups zone together" do
      tgt_time = 2.hours.ago
      zone1 = FactoryGirl.create(:zone, :name => "zone1")
      zone2 = FactoryGirl.create(:zone, :name => "zone2")
      MiqQueue.put(:zone => zone1.name, :class_name => "X", :method_name => "x", :created_on => tgt_time)
      MiqQueue.put(:zone => zone2.name, :class_name => "X", :method_name => "x", :created_on => tgt_time)
      expect(described_class.queue_status).to eq(
        [
          {
            "Zone"   => "zone1",
            "Queue"  => "generic",
            "Role"   => nil,
            "method" => "X.x",
            "oldest" => tgt_time.strftime("%Y-%m-%d"),
            "count"  => 1,
          },
          {
            "Zone"   => "zone2",
            "Queue"  => "generic",
            "Role"   => nil,
            "method" => "X.x",
            "oldest" => tgt_time.strftime("%Y-%m-%d"),
            "count"  => 1,
          }
        ]
      )
    end
  end

  context ".update_start" do
    it "was running" do
      expect(FileUtils).to receive(:mkdir_p).once
      expect(File).to receive(:file?).once.and_return(true)
      expect(File).to receive(:write).once
      expect(FileUtils).to receive(:rm_f).once

      described_class.update_start
    end

    it "was not running" do
      expect(FileUtils).to receive(:mkdir_p).once
      expect(FileUtils).to receive(:rm_f).once

      described_class.update_start
    end
  end

  context ".update_stop" do
    it "was running" do
      EvmSpecHelper.create_guid_miq_server_zone
      expect(FileUtils).to receive(:mkdir_p)
      expect(File).to receive(:write)
      expect(EvmApplication).to receive(:stop)

      described_class.update_stop
    end

    it "was not running" do
      _, server, = EvmSpecHelper.create_guid_miq_server_zone
      server.update_attribute(:status, "stopped")

      described_class.update_stop
    end
  end

  describe ".set_region_file" do
    let(:region_file) { Pathname.new(Tempfile.new("REGION").path) }

    after do
      FileUtils.rm_f(region_file)
    end

    context "when the region file exists" do
      it "writes the new region if the regions differ" do
        old_region = 1
        new_region = 4

        region_file.write(old_region)
        described_class.set_region_file(region_file, new_region)
        expect(region_file.read).to eq(new_region.to_s)
      end

      it "does not write the region if the regions are the same" do
        old_region = 1
        new_region = 1

        region_file.write(old_region)
        expect(region_file).not_to receive(:write)

        described_class.set_region_file(region_file, new_region)
      end
    end

    context "when the region file does not exist" do
      before do
        FileUtils.rm_f(region_file)
      end

      it "creates the file with the new region number" do
        new_region = 4

        described_class.set_region_file(region_file, new_region)
        expect(region_file.read).to eq(new_region.to_s)
      end
    end
  end

  describe ".deployment_status" do
    it "returns new_deployment if the database is not migrated" do
      expect(ActiveRecord::Migrator).to receive(:current_version).and_return(0)
      expect(described_class.deployment_status).to eq("new_deployment")
    end

    it "returns new_replica if the current server is not seeded" do
      expect(described_class.deployment_status).to eq("new_replica")
    end

    it "returns upgrade if we need to migrate the database" do
      EvmSpecHelper.local_miq_server
      expect(ActiveRecord::Migrator).to receive(:needs_migration?).and_return(true)
      expect(described_class.deployment_status).to eq("upgrade")
    end

    it "returns redeployment otherwise" do
      EvmSpecHelper.local_miq_server
      expect(described_class.deployment_status).to eq("redeployment")
    end
  end

  describe ".encryption_key_valid?" do
    it "returns true when we are using the correct encryption key" do
      expect(described_class.encryption_key_valid?).to be_truthy
    end
  end
end
