require "spec_helper"

describe "MiqServer" do
  context "RhnMirror" do
    before do
      MiqDatabase.seed
      MiqRegion.seed
      ServerRole.seed
      _, @server1, zone = EvmSpecHelper.create_guid_miq_server_zone
      @server1.update_attribute(:ipaddress, "1.2.3.4")
      @server2  = FactoryGirl.create(:miq_server_not_master, :guid => MiqUUID.new_guid, :zone => zone, :ipaddress => "9.8.7.6")
    end

    context "#configure_rhn_mirror_client" do
      it "should configure when not hosting content" do
        @server2.assign_role("rhn_mirror")

        FileUtils.should_not_receive(:rm_f)
        File.should_receive(:read).with("/etc/hosts").and_return("\n #Some Comment\n127.0.0.1\tlocalhost")
        File.should_receive(:write).with("/etc/hosts", "\n#Some Comment\n127.0.0.1        localhost\n#{@server1.ipaddress}          #{@server1.guid}\n#{@server2.ipaddress}          #{@server2.guid}")
        MiqServer.any_instance.should_receive(:write_yum_repo_file).with([@server2])

        @server1.configure_rhn_mirror_client
      end

      it "should not configure when hosting content" do
        @server1.assign_role("rhn_mirror")

        FileUtils.should_receive(:rm_f).once

        @server1.configure_rhn_mirror_client
      end
    end

    it "#resync_rhn_mirror" do
      rpm_file_list       = ["/repo/mirror/abc-1.2.3-1.el6_0.2.i686.rpm", "/repo/mirror/abc-4.5.6-7.el6_4.x86_64.rpm", "/repo/mirror/def-B.02abc.1r6-4.el6cf.x86_64.rpm", "/repo/mirror/ghi-2013c-2.el6.noarch.rpm"]
      parsed_package_list = {"abc"=>{"1.2.3.1"=>"/repo/mirror/abc-1.2.3-1.el6_0.2.i686.rpm","4.5.6.7"=>"/repo/mirror/abc-4.5.6-7.el6_4.x86_64.rpm"}, "def-B"=>{"02.1.6.4"=>"/repo/mirror/def-B.02abc.1r6-4.el6cf.x86_64.rpm"}, "ghi"=>{"2013.2"=>"/repo/mirror/ghi-2013c-2.el6.noarch.rpm"}}

      FileUtils.should_receive(:mkdir_p).with("/repo/mirror")
      MiqApache::Conf.should_receive(:create_conf_file).once.and_return(true)
      FileUtils.should_receive(:rm).with("/etc/httpd/conf.d/cfme-https-mirror.conf", {:force=>true})
      MiqApache::Control.should_receive(:restart).once
      LinuxAdmin::Yum.should_receive(:download_packages).once.with("/repo/mirror", "cfme-appliance")
      Dir.should_receive(:glob).with("/repo/mirror/**/*.rpm").and_return(rpm_file_list)
      @server1.should_receive(:remove_old_versions).with(parsed_package_list).and_call_original
      FileUtils.should_receive(:rm).with("/repo/mirror/abc-1.2.3-1.el6_0.2.i686.rpm")
      LinuxAdmin::Yum.should_receive(:create_repo).with("/repo/mirror")

      @server1.resync_rhn_mirror

      expect(MiqQueue.count).to eq(2)
    end
  end
end
