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

  describe ".status" do
    def header(col, adjust = :rjust)
      hdr = col == :WID ? "ID" : col.to_s # edge case
      hdr.gsub("_", " ").send(adjust, send("#{col.downcase}_padding"))
    end

    def line_for(col)
      "-" * send("#{col.downcase}_padding")
    end

    def pad(val, col)
      val.to_s.rjust(send("#{col.downcase}_padding"))
    end

    let(:local)    { EvmSpecHelper.local_miq_server }
    let(:remote)   { EvmSpecHelper.remote_miq_server(:is_master => true) }
    let!(:ui)      { FactoryGirl.create(:miq_ui_worker, :miq_server => local, :pid => 80000) }
    let!(:socket)  { FactoryGirl.create(:miq_websocket_worker, :miq_server => local, :pid => 7000) }
    let!(:generic) { FactoryGirl.create(:miq_generic_worker, :miq_server => remote) }
    let!(:refresh) { FactoryGirl.create(:miq_ems_refresh_worker, :miq_server => remote) }

    let(:local_started_on)  { local.started_on.iso8601 }
    let(:local_heartbeat)   { local.last_heartbeat.iso8601 }

    let(:id_padding)        { [2, local.id.to_s.size].max }
    let(:pid_padding)       { ["PID", ui.pid.to_s, socket.pid.to_s].map(&:size).max }
    let(:server_id_padding) { [9, local.id.to_s.size].max }
    let(:wid_padding)       { ["ID", ui.id.to_s, socket.id.to_s].map(&:size).max }
    let(:zone_padding)      { local.zone.name.to_s.size }

    before do
      allow(described_class).to receive(:puts).with("Checking EVM status...")
      allow(described_class).to receive(:puts).with("\n")
    end

    context "for just the local server" do
      it "displays server status for the local server and it's workers" do
        server_info = <<-SERVER_INFO.strip_heredoc
           #{header(:Zone, :ljust)} | Server                   | Status  | #{header(:ID)       } | PID | SPID | URL | Started              | Heartbeat            | MB Usage | Master? | Roles
          -#{line_for(:Zone)      }-+--------------------------+---------+-#{line_for(:ID)     }-+-----+------+-----+----------------------+----------------------+----------+---------+-------
           #{local.zone.name      } | #{      local.name     } | started | #{pad(local.id, :ID)} |     |      |     | #{local_started_on } | #{local_heartbeat  } |          | false   |
        SERVER_INFO
        worker_info = <<-WORKER_INFO.strip_heredoc
           Worker Type        | Status | #{header(:WID)        } | #{header(:PID)         } | SPID | #{header(:Server_id)       } | Queue | Started | Heartbeat | MB Usage
          --------------------+--------+-#{line_for(:WID)      }-+-#{line_for(:PID)       }-+------+-#{line_for(:Server_id)     }-+-------+---------+-----------+----------
           MiqUiWorker        | ready  | #{pad(ui.id, :WID)    } | #{pad(ui.pid, :PID)    } |      | #{pad(local.id, :Server_id)} |       |         |           |
           MiqWebsocketWorker | ready  | #{pad(socket.id, :WID)} | #{pad(socket.pid, :PID)} |      | #{pad(local.id, :Server_id)} |       |         |           |
        WORKER_INFO

   expect(described_class).to receive(:puts).with(server_info)
        expect(described_class).to receive(:puts).with(worker_info)

        EvmApplication.status
      end
    end

    context "with remote servers" do
      let(:remote_started_on) { remote.started_on.iso8601 }
      let(:remote_heartbeat)  { remote.last_heartbeat.iso8601 }

      let(:id_padding)        { ["ID", local.id.to_s, remote.id.to_s].map(&:size).max }
      let(:pid_padding)       { MiqWorker.all.pluck(:pid).map { |pid| pid.to_s.size }.unshift(3).max }
      let(:server_id_padding) { [9, local.id.to_s.size, remote.id.to_s.size].max }
      let(:wid_padding)       { MiqWorker.all.pluck(:id).map { |pid| pid.to_s.size }.unshift(2).max }
      let(:zone_padding)      { ["Zone", local.zone.name.to_s, remote.zone.name.to_s].map(&:size).max }

      it "displays server status for the all servers and workers" do
        server_info = <<-SERVER_INFO.strip_heredoc
           #{header(:Zone, :ljust)} | Server                   | Status  | #{header(:ID)        } | PID | SPID | URL | Started              | Heartbeat            | MB Usage | Master? | Roles
          -#{line_for(:Zone)      }-+--------------------------+---------+-#{line_for(:ID)      }-+-----+------+-----+----------------------+----------------------+----------+---------+-------
           #{local.zone.name      } | #{      local.name     } | started | #{pad(local.id, :ID) } |     |      |     | #{local_started_on } | #{local_heartbeat  } |          | false   |
           #{remote.zone.name     } | #{      remote.name    } | started | #{pad(remote.id, :ID)} |     |      |     | #{remote_started_on} | #{remote_heartbeat } |          | true    |
        SERVER_INFO
        worker_info = <<-WORKER_INFO.strip_heredoc
           Worker Type                                     | Status | #{header(:WID)         } | #{header(:PID)          } | SPID | #{header(:Server_id)        } | Queue | Started | Heartbeat | MB Usage
          -------------------------------------------------+--------+-#{line_for(:WID)       }-+-#{line_for(:PID)        }-+------+-#{line_for(:Server_id)      }-+-------+---------+-----------+----------
           MiqUiWorker                                     | ready  | #{pad(ui.id, :WID)     } | #{pad(ui.pid, :PID)     } |      | #{pad(local.id, :Server_id) } |       |         |           |
           MiqWebsocketWorker                              | ready  | #{pad(socket.id, :WID) } | #{pad(socket.pid, :PID) } |      | #{pad(local.id, :Server_id) } |       |         |           |
           ManageIQ::Providers::BaseManager::RefreshWorker | ready  | #{pad(refresh.id, :WID)} | #{pad(refresh.pid, :PID)} |      | #{pad(remote.id, :Server_id)} |       |         |           |
           MiqGenericWorker                                | ready  | #{pad(generic.id, :WID)} | #{pad(generic.pid, :PID)} |      | #{pad(remote.id, :Server_id)} |       |         |           |
        WORKER_INFO

        expect(described_class).to receive(:puts).with(server_info)
        expect(described_class).to receive(:puts).with(worker_info)

        EvmApplication.status(true)
      end
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
