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

    let(:local)    { EvmSpecHelper.local_miq_server(:version => '9.9.9.9', :last_heartbeat => 2.day.ago) }
    let(:remote)   { EvmSpecHelper.remote_miq_server(:is_master => true, :version => '9.9.9.8', :last_heartbeat => nil) }
    let(:rgn)      { local.region_number }
    let!(:ui)      { FactoryGirl.create(:miq_ui_worker, :miq_server => local, :pid => 80000) }
    let!(:socket)  { FactoryGirl.create(:miq_websocket_worker, :miq_server => local, :pid => 7000) }
    let!(:generic) { FactoryGirl.create(:miq_generic_worker, :miq_server => remote) }
    let!(:refresh) { FactoryGirl.create(:miq_ems_refresh_worker, :miq_server => remote) }

    let(:local_started_on)  { local.started_on.iso8601 }
    let(:local_heartbeat)   { local.last_heartbeat.iso8601 }

    let(:pid_padding)       { ["PID", ui.pid.to_s, socket.pid.to_s].map(&:size).max }
    let(:zone_padding)      { local.zone.name.to_s.size }

    before do
      allow(described_class).to receive(:puts).with("Checking EVM status...")
      allow(described_class).to receive(:puts).with("\n")
    end

    context "for just the local server" do
      it "displays server status for the local server and it's workers" do
        server_info = <<-SERVER_INFO.strip_heredoc
           Rgn #{  }| #{header(:Zone, :ljust)} | Server                   | Status  | PID | SPID | Workers | Version | Started              | Heartbeat            | MB Usage | Roles
          -----#{  }+-#{line_for(:Zone)      }-+--------------------------+---------+-----+------+---------+---------+----------------------+----------------------+----------+-------
             #{rgn} | #{local.zone.name      } | #{      local.name     } | started |     |      |       2 | 9.9.9.9 | #{local_started_on } | #{local_heartbeat  } |          |
        SERVER_INFO
        worker_info = <<-WORKER_INFO.strip_heredoc
           Rgn #{  }| #{header(:Zone, :ljust)} | Type      | Status | #{header(:PID)         } | SPID | Server                   | Queue | Started | Heartbeat | MB Usage
          -----#{  }+-#{line_for(:Zone)      }-+-----------+--------+-#{line_for(:PID)       }-+------+--------------------------+-------+---------+-----------+----------
             #{rgn} | #{local.zone.name      } | Ui        | ready  | #{pad(ui.pid, :PID)    } |      | #{      local.name     } |       |         |           |
             #{rgn} | #{local.zone.name      } | Websocket | ready  | #{pad(socket.pid, :PID)} |      | #{      local.name     } |       |         |           |
        WORKER_INFO

   expect(described_class).to receive(:puts).with(server_info)
        expect(described_class).to receive(:puts).with(worker_info)

        EvmApplication.status
      end
    end

    context "with remote servers" do
      let(:remote_started_on) { remote.started_on.iso8601 }

      let(:pid_padding)       { MiqWorker.all.pluck(:pid).map { |pid| pid.to_s.size }.unshift(3).max }
      let(:zone_padding)      { ["Zone", local.zone.name.to_s, remote.zone.name.to_s].map(&:size).max }

      it "displays server status for the all servers and workers" do
        server_info = <<-SERVER_INFO.strip_heredoc
           Rgn #{  }| #{header(:Zone, :ljust)} | Server                    | Status  | PID | SPID | Workers | Version | Started              | Heartbeat            | MB Usage | Roles
          -----#{  }+-#{line_for(:Zone)      }-+---------------------------+---------+-----+------+---------+---------+----------------------+----------------------+----------+-------
             #{rgn} | #{local.zone.name      } | #{      local.name     }  | started |     |      |       2 | 9.9.9.9 | #{local_started_on } | #{local_heartbeat  } |          |
             #{rgn} | #{remote.zone.name     } | #{     remote.name     }* | started |     |      |       2 | 9.9.9.8 | #{remote_started_on} |                      |          |
        SERVER_INFO
        worker_info = <<-WORKER_INFO.strip_heredoc
           Rgn #{  }| #{header(:Zone, :ljust)} | Type          | Status | #{header(:PID)          } | SPID | Server                   | Queue | Started | Heartbeat | MB Usage
          -----#{  }+-#{line_for(:Zone)      }-+---------------+--------+-#{line_for(:PID)        }-+------+--------------------------+-------+---------+-----------+----------
             #{rgn} | #{local.zone.name      } | Ui            | ready  | #{pad(ui.pid, :PID)     } |      | #{      local.name     } |       |         |           |
             #{rgn} | #{local.zone.name      } | Websocket     | ready  | #{pad(socket.pid, :PID) } |      | #{      local.name     } |       |         |           |
             #{rgn} | #{remote.zone.name     } | Base::Refresh | ready  | #{pad(refresh.pid, :PID)} |      | #{     remote.name     } |       |         |           |
             #{rgn} | #{remote.zone.name     } | Generic       | ready  | #{pad(generic.pid, :PID)} |      | #{     remote.name     } |       |         |           |
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
