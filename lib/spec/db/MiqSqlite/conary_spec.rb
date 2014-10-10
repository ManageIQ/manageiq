require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. db})))
require 'MiqSqlite/MiqSqlite3'

describe MiqSqlite3DB::MiqSqlite3 do

  let(:fname) { "#{File.dirname(__FILE__)}/conary.db"}
  let(:db)    { MiqSqlite3DB::MiqSqlite3.new(fname)}

  after do
    db.close
  end

  it "#table_names" do
    expected = %w{
      DBFileTags
      DBFlavorMap
      DBTroveFiles
      DataStore
      DatabaseAttributes
      DatabaseVersion
      Dependencies
      Flavors
      Instances
      Provides
      Requires
      Tags
      TroveInfo
      TroveTroves
      Versions
      sqlite_sequence
    }

    expect(db.table_names.sort).to eql(expected)
  end

  it "#npages" do
    expect(db.npages).to eql(16699)
  end

  it "btree" do
    tVersions  = db.getTable("Versions")
    tInstances = db.getTable("Instances")

    versions = Hash.new
    tVersions.each_row { |row|
      id           = row['versionId']
      versions[id] = row['version']
    }

    troves = Hash.new
    tInstances.each_row { |row|
      troveName = row['troveName']
      versionId = row['versionId']
      if versions.has_key?(versionId) && !troveName.include?(":") && row['isPresent']
        troves[troveName] = {
          :versionID => versionId,
          :version   => versions[versionId]
        }
      end
    }

    expected = {
      "info-disk"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-emerge"=>
        {:versionID => 3, :version => "/conary.rpath.com@rpl:devel//1/2-2-0.1"},
      "info-floppy"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-kmem"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-uucp"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-apache"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-daemon"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-lock"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-lp"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-mail"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-mailnull"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-mysql"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-ntp"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-raa-web"=>
        {:versionID => 4, :version => "/raa.rpath.org@rpath:raa-devel//raa-2/1-1-1"},
      "info-smmsp"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-sshd"=>
        {:versionID => 6, :version => "/conary.rpath.com@rpl:devel//1/1-3-0.1"},
      "info-tty"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-users"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "info-utmp"=>
        {:versionID => 1, :version => "/conary.rpath.com@rpl:devel//1/1-1-0.1"},
      "distro-release"=>
        {:versionID => 7,
        :version =>
         "/conary.rpath.com@rpl:devel//1//vehera-base.rpath.org@rpl:devel/1.6.10-0.0.1-2"},
      "raa-plugin-rPath"=>
        {:versionID => 11,
        :version => "/raa.rpath.org@rpath:raa-devel//raa-2/1.0.0-1-1"},
      "rootfiles"=>
        {:versionID => 13, :version => "/conary.rpath.com@rpl:devel//1/7.2-4-0.1"},
      "termcap"=>
        {:versionID => 15, :version => "/conary.rpath.com@rpl:devel//1/11.0.1-3-0.1"},
      "dev"=>
        {:versionID => 20, :version => "/conary.rpath.com@rpl:devel//1/3.19-4-0.2"},
      "filesystem"=>
        {:versionID => 38, :version => "/conary.rpath.com@rpl:devel//1/2.2.1-8.1-1"},
      "hwdata"=>
        {:versionID => 53, :version => "/conary.rpath.com@rpl:devel//1/0.158.1-2.4-1"},
      "mailbase"=>
        {:versionID => 70, :version => "/conary.rpath.com@rpl:devel//1/1.0-6-0.1"},
      "mailcap"=>
        {:versionID => 91, :version => "/conary.rpath.com@rpl:devel//1/2.1.14-4-0.1"},
      "bash"=>
        {:versionID => 168, :version => "/conary.rpath.com@rpl:devel//1/3.0.16-7-0.1"},
      "coreutils"=>
        {:versionID => 172, :version => "/conary.rpath.com@rpl:devel//1/5.2.1-12-0.1"},
      "cpio"=>
        {:versionID => 171, :version => "/conary.rpath.com@rpl:devel//1/2.6-6-0.1"},
      "cracklib"=>
        {:versionID => 160, :version => "/conary.rpath.com@rpl:devel//1/2.7-8-0.1"},
      "db"=>
        {:versionID => 133, :version => "/conary.rpath.com@rpl:devel//1/4.3.28-6-0.1"},
      "e2fsprogs"=>
        {:versionID => 45, :version => "/conary.rpath.com@rpl:devel//1/1.37-3-0.1"},
      "findutils"=>
        {:versionID => 154, :version => "/conary.rpath.com@rpl:devel//1/4.2.23-2-0.1"},
      "gawk"=>
        {:versionID => 66, :version => "/conary.rpath.com@rpl:devel//1/3.1.4-3-0.1"},
      "glibc"=>
        {:versionID => 142, :version => "/conary.rpath.com@rpl:devel//1/2.3.6-8.7-1"},
      "grep"=>
        {:versionID => 163, :version => "/conary.rpath.com@rpl:devel//1/2.5.1-13-0.1"},
      "gzip"=>
        {:versionID => 135, :version => "/conary.rpath.com@rpl:devel//1/1.3.5-4-0.1"},
      "kernel"=>
        {:versionID => 593, :version => "/conary.rpath.com@rpl:devel//1/2.6.19.7-0.3-1"},
      "libgcc"=>
        {:versionID => 145, :version => "/conary.rpath.com@rpl:devel//1/3.4.4-9.4-1"},
      "libstdc++"=>
        {:versionID => 145, :version => "/conary.rpath.com@rpl:devel//1/3.4.4-9.4-1"},
      "libtermcap"=>
        {:versionID => 175, :version => "/conary.rpath.com@rpl:devel//1/2.0.8-9-0.1"},
      "mkinitrd"=>
        {:versionID => 180, :version => "/conary.rpath.com@rpl:devel//1/4.2.15-16.3-1"},
      "mktemp"=>
        {:versionID => 134, :version => "/conary.rpath.com@rpl:devel//1/1.5-18-0.1"},
      "module-init-tools"=>
        {:versionID => 183, :version => "/conary.rpath.com@rpl:devel//1/3.1-5-0.1"},
      "pam"=>
        {:versionID => 137, :version => "/conary.rpath.com@rpl:devel//1/0.79-5-0.1"},
      "pcre"=>
        {:versionID => 147, :version => "/conary.rpath.com@rpl:devel//1/5.0-6-0.1"},
      "sed"=>
        {:versionID => 167, :version => "/conary.rpath.com@rpl:devel//1/4.1.4-7-0.1"},
      "slang"=>
        {:versionID => 152, :version => "/conary.rpath.com@rpl:devel//1/1.4.9-3-0.1"},
      "tar"=>
        {:versionID => 162, :version => "/conary.rpath.com@rpl:devel//1/1.15.1-7.1-1"},
      "udev"=>
        {:versionID => 125, :version => "/conary.rpath.com@rpl:devel//1/069-5-0.1"},
      "util-linux"=>
        {:versionID => 155, :version => "/conary.rpath.com@rpl:devel//1/2.12r-1-0.1"},
      "zlib"=>
        {:versionID => 185, :version => "/conary.rpath.com@rpl:devel//1/1.2.3-1-0.1"},
      "PyPAM"=>
        {:versionID => 189, :version => "/conary.rpath.com@rpl:devel//1/0.4.2-3-0.1"},
      "VMwareTools-kernel"=>
        {:versionID => 192,
        :version => "/addons.rpath.com@rpl:devel//1/5.5.3_34685-2-0.2"},
      "alsa-lib"=>
        {:versionID => 28, :version => "/conary.rpath.com@rpl:devel//1/1.0.9-2-0.1"},
      "apr"=>
        {:versionID => 193, :version => "/conary.rpath.com@rpl:devel//1/0.9.7-1-0.1"},
      "ash"=>
        {:versionID => 196, :version => "/conary.rpath.com@rpl:devel//1/0.3.8-10-0.1"},
      "aspell"=>
        {:versionID => 198, :version => "/conary.rpath.com@rpl:devel//1/0.60.2-7-0.1"},
      "acl"=>
        {:versionID => 203, :version => "/conary.rpath.com@rpl:devel//1/2.2.28-2-0.1"},
      "attr"=>
        {:versionID => 201, :version => "/conary.rpath.com@rpl:devel//1/2.4.20-3-0.1"},
      "audiofile"=>
        {:versionID => 205, :version => "/conary.rpath.com@rpl:devel//1/0.2.6-6-0.1"},
      "bzip2"=>
        {:versionID => 207, :version => "/conary.rpath.com@rpl:devel//1/1.0.4-1-0.1"},
      "cElementTree"=>
        {:versionID => 208, :version => "/conary.rpath.com@rpl:devel//1/1.0.5-4-0.1"},
      "crontabs"=>
        {:versionID => 210, :version => "/conary.rpath.com@rpl:devel//1/1.10-5-0.1"},
      "cyrus-sasl"=>
        {:versionID => 213, :version => "/conary.rpath.com@rpl:devel//1/2.1.21-5-0.1"},
      "device-mapper"=>
        {:versionID => 215, :version => "/conary.rpath.com@rpl:devel//1/1.01.01-2-0.1"},
      "diffutils"=>
        {:versionID => 217, :version => "/conary.rpath.com@rpl:devel//1/2.8.1-8-0.1"},
      "esound"=>
        {:versionID => 218, :version => "/conary.rpath.com@rpl:devel//1/0.2.36-1-0.1"},
      "expat"=>
        {:versionID => 220, :version => "/conary.rpath.com@rpl:devel//1/1.95.8-5-0.1"},
      "file"=>
        {:versionID => 36, :version => "/conary.rpath.com@rpl:devel//1/4.20-1-0.1"},
      "freetype"=>
        {:versionID => 222, :version => "/conary.rpath.com@rpl:devel//1/2.1.10-5.1-1"},
      "fontconfig"=>
        {:versionID => 223, :version => "/conary.rpath.com@rpl:devel//1/2.3.2-6.3-1"},
      "gamin"=>
        {:versionID => 226, :version => "/conary.rpath.com@rpl:devel//1/0.1.7-0.1-2"},
      "gdbm"=>
        {:versionID => 229, :version => "/conary.rpath.com@rpl:devel//1/1.8.0-12-0.1"},
      "glib"=>
        {:versionID => 231, :version => "/conary.rpath.com@rpl:devel//1/2.8.3-1-0.1"},
      "atk"=>
        {:versionID => 234, :version => "/conary.rpath.com@rpl:devel//1/1.10.3-1-0.1"},
      "gmp"=>
        {:versionID => 236, :version => "/conary.rpath.com@rpl:devel//1/4.1.4-10-0.1"},
      "gnome-keyring"=>
        {:versionID => 238, :version => "/conary.rpath.com@rpl:devel//1/0.4.5-1-0.1"},
      "gpm"=>
        {:versionID => 240, :version => "/conary.rpath.com@rpl:devel//1/1.20.1-13-0.1"},
      "grub"=>
        {:versionID => 51, :version => "/conary.rpath.com@rpl:devel//1/0.95-5-0.1"},
      "hesiod"=>
        {:versionID => 244, :version => "/conary.rpath.com@rpl:devel//1/3.0.2-6-0.1"},
      "hotplug"=>
        {:versionID => 245,
        :version => "/conary.rpath.com@rpl:devel//1/2004_03_29-19.3-1"},
      "howl"=>
        {:versionID => 55, :version => "/conary.rpath.com@rpl:devel//1/1.0.0-4-0.1"},
      "iproute"=>
        {:versionID => 252,
        :version => "/conary.rpath.com@rpl:devel//1/2.6.11.050330-4-0.1"},
      "iptables"=>
        {:versionID => 258, :version => "/conary.rpath.com@rpl:devel//1/1.3.1-4-0.1"},
      "iputils"=>
        {:versionID => 261, :version => "/conary.rpath.com@rpl:devel//1/20020927-5-0.1"},
      "krb5"=>
        {:versionID => 86, :version => "/conary.rpath.com@rpl:devel//1/1.4.1-7.6-1"},
      "libIDL"=>
        {:versionID => 265, :version => "/conary.rpath.com@rpl:devel//1/0.8.6-2-0.1"},
      "libart_lgpl"=>
        {:versionID => 267, :version => "/conary.rpath.com@rpl:devel//1/2.3.17-1-0.1"},
      "libcap"=>
        {:versionID => 269, :version => "/conary.rpath.com@rpl:devel//1/1.10-4-0.1"},
      "libelf-lgpl"=>
        {:versionID => 271, :version => "/conary.rpath.com@rpl:devel//1/0.8.6-4-0.1"},
      "libelf"=>
        {:versionID => 273, :version => "/conary.rpath.com@rpl:devel//1/0.108-4-0.1"},
      "libjpeg"=>
        {:versionID => 275, :version => "/conary.rpath.com@rpl:devel//1/6b-7-0.1"},
      "libpng"=>
        {:versionID => 277, :version => "/conary.rpath.com@rpl:devel//1/1.2.13-0.1-1"},
      "libtiff"=>
        {:versionID => 278, :version => "/conary.rpath.com@rpl:devel//1/3.8.2-3-0.1"},
      "libtool"=>
        {:versionID => 279, :version => "/conary.rpath.com@rpl:devel//1/1.5.20-1-0.1"},
      "m4"=>
        {:versionID => 285, :version => "/conary.rpath.com@rpl:devel//1/1.4.3-4-0.1"},
      "make"=>
        {:versionID => 295, :version => "/conary.rpath.com@rpl:devel//1/3.80-7-0.1"},
      "mdadm"=>
        {:versionID => 296, :version => "/conary.rpath.com@rpl:devel//1/1.11.0-2-0.1"},
      "mingetty"=>
        {:versionID => 298, :version => "/conary.rpath.com@rpl:devel//1/1.07-5-0.1"},
      "ncurses"=>
        {:versionID => 119, :version => "/conary.rpath.com@rpl:devel//1/5.4-3.3-1"},
      "net-tools"=>
        {:versionID => 300, :version => "/conary.rpath.com@rpl:devel//1/1.60-8-0.1"},
      "newt"=>
        {:versionID => 302, :version => "/conary.rpath.com@rpl:devel//1/0.51.6-4.1-1"},
      "curl"=>
        {:versionID => 307, :version => "/conary.rpath.com@rpl:devel//1/7.15.3-1-0.1"},
      "openldap"=>
        {:versionID => 115, :version => "/conary.rpath.com@rpl:devel//1/2.2.26-8.6-1"},
      "apr-util"=>
        {:versionID => 193, :version => "/conary.rpath.com@rpl:devel//1/0.9.7-1-0.1"},
      "openssh-client"=>
        {:versionID => 310, :version => "/conary.rpath.com@rpl:devel//1/4.5p1-0.1-1"},
      "openssh"=>
        {:versionID => 310, :version => "/conary.rpath.com@rpl:devel//1/4.5p1-0.1-1"},
      "openssl"=>
        {:versionID => 117, :version => "/conary.rpath.com@rpl:devel//1/0.9.7f-10.6-1"},
      "perl-DBI"=>
        {:versionID => 316, :version => "/conary.rpath.com@rpl:devel//1/1.48-3.1-1"},
      "perl-DBD-MySQL"=>
        {:versionID => 325, :version => "/conary.rpath.com@rpl:devel//1/2.9007-3.2-2"},
      "perl"=>
        {:versionID => 320, :version => "/conary.rpath.com@rpl:devel//1/5.8.7-8-0.2"},
      "VMwareTools"=>
        {:versionID => 190,
        :version => "/addons.rpath.com@rpl:devel//1/5.5.3_34685-5.1-1"},
      "mysql"=>
        {:versionID => 100, :version => "/conary.rpath.com@rpl:devel//1/5.0.33-1-0.1"},
      "php"=>
        {:versionID => 111, :version => "/conary.rpath.com@rpl:devel//1/4.3.11-15.10-1"},
      "php-mysql"=>
        {:versionID => 111, :version => "/conary.rpath.com@rpl:devel//1/4.3.11-15.10-1"},
      "popt"=>
        {:versionID => 335, :version => "/conary.rpath.com@rpl:devel//1/1.8.1-10-0.1"},
      "ORBit2"=>
        {:versionID => 26, :version => "/conary.rpath.com@rpl:devel//1/2.12.4-1-0.1"},
      "libbonobo"=>
        {:versionID => 73, :version => "/conary.rpath.com@rpl:devel//1/2.10.1-1-0.1"},
      "libuser"=>
        {:versionID => 290, :version => "/conary.rpath.com@rpl:devel//1/0.53.8-6-0.1"},
      "logrotate"=>
        {:versionID => 78, :version => "/conary.rpath.com@rpl:devel//1/3.7.1-2-0.1"},
      "passwd"=>
        {:versionID => 341, :version => "/conary.rpath.com@rpl:devel//1/0.68-4-0.1"},
      "procmail"=>
        {:versionID => 343, :version => "/conary.rpath.com@rpl:devel//1/3.22-7-0.1"},
      "procps"=>
        {:versionID => 345, :version => "/conary.rpath.com@rpl:devel//1/3.2.7-0.1-2"},
      "psmisc"=>
        {:versionID => 347, :version => "/conary.rpath.com@rpl:devel//1/21.6-4-0.1"},
      "raa-backup-mysql"=>
        {:versionID => 349, :version => "/raa.rpath.org@rpath:raa-devel//raa-2/1.0-1-2"},
      "readline"=>
        {:versionID => 352, :version => "/conary.rpath.com@rpl:devel//1/5.0-2-0.1"},
      "lvm2"=>
        {:versionID => 353, :version => "/conary.rpath.com@rpl:devel//1/2.01.14-2-0.1"},
      "ConfigObj"=>
        {:versionID => 359, :version => "/conary.rpath.com@rpl:devel//1/4.3.1-1-0.1"},
      "PIL"=>
        {:versionID => 365, :version => "/conary.rpath.com@rpl:devel//1/1.1.6b1-1-0.1"},
      "Cheetah"=>
        {:versionID => 367, :version => "/conary.rpath.com@rpl:devel//1/1.0-1-0.1"},
      "PyProtocols"=>
        {:versionID => 369,
        :version => "/conary.rpath.com@rpl:devel//1/1.0a0dev_r2082-1-0.1"},
      "RuleDispatch"=>
        {:versionID => 371,
        :version => "/conary.rpath.com@rpl:devel//1/0.5a0dev_r2097-2-0.1"},
      "epdb"=>
        {:versionID => 373, :version => "/conary.rpath.com@rpl:devel//1/0.9.1.1-1-0.1"},
      "libxml2"=>
        {:versionID => 293, :version => "/conary.rpath.com@rpl:devel//1/2.6.22-1.1-1"},
      "libxslt"=>
        {:versionID => 284, :version => "/conary.rpath.com@rpl:devel//1/1.1.15-1.2-1"},
      "mx"=>
        {:versionID => 377, :version => "/conary.rpath.com@rpl:devel//1/2.0.6-2.1-2"},
      "postgresql"=>
        {:versionID => 380, :version => "/conary.rpath.com@rpl:devel//1/8.1.8-0.1-1"},
      "perl-DBD-Pg"=>
        {:versionID => 382, :version => "/conary.rpath.com@rpl:devel//1/1.42-4.1-2"},
      "pycrypto"=>
        {:versionID => 385, :version => "/conary.rpath.com@rpl:devel//1/2.0.1-9-0.1"},
      "python-setuptools"=>
        {:versionID => 387, :version => "/conary.rpath.com@rpl:devel//1/0.6a11-1-0.1"},
      "PasteDeploy"=>
        {:versionID => 389, :version => "/conary.rpath.com@rpl:devel//1/0.5-3-0.1"},
      "PasteScript"=>
        {:versionID => 391, :version => "/conary.rpath.com@rpl:devel//1/0.5.1-2-0.1"},
      "python"=>
        {:versionID => 357, :version => "/conary.rpath.com@rpl:devel//1/2.4.1-20.8-1"},
      "simplejson"=>
        {:versionID => 395, :version => "/conary.rpath.com@rpl:devel//1/1.3-2-0.1"},
      "samba"=>
        {:versionID => 398, :version => "/conary.rpath.com@rpl:devel//1/3.0.24-0.1-1"},
      "scgi"=>
        {:versionID => 399, :version => "/conary.rpath.com@rpl:devel//1/1.10-9-0.1"},
      "setup"=>
        {:versionID => 401, :version => "/conary.rpath.com@rpl:devel//1/2.5.47-6.2-1"},
      "sgmlop"=>
        {:versionID => 408, :version => "/conary.rpath.com@rpl:devel//1/1.1.1-5.1-2"},
      "elementtree"=>
        {:versionID => 410,
        :version => "/conary.rpath.com@rpl:devel//1/1.2.6.20050316-8-0.1"},
      "FormEncode"=>
        {:versionID => 391, :version => "/conary.rpath.com@rpl:devel//1/0.5.1-2-0.1"},
      "Paste"=>
        {:versionID => 414, :version => "/conary.rpath.com@rpl:devel//1/0.9-3-0.1"},
      "kid"=>
        {:versionID => 416, :version => "/conary.rpath.com@rpl:devel//1/0.9.1-2-0.1"},
      "TurboKid"=>
        {:versionID => 420, :version => "/conary.rpath.com@rpl:devel//1/0.9a5-1-0.1"},
      "shadow"=>
        {:versionID => 422, :version => "/conary.rpath.com@rpl:devel//1/4.0.7-14-0.1"},
      "sqlite"=>
        {:versionID => 427, :version => "/conary.rpath.com@rpl:devel//1/3.2.2-8-0.1"},
      "conary"=>
        {:versionID => 429, :version => "/conary.rpath.com@rpl:devel//1/1.1.22-0.1-1"},
      "python-sqlite"=>
        {:versionID => 452, :version => "/conary.rpath.com@rpl:devel//1/2.0.5-3-0.1"},
      "SQLObject"=>
        {:versionID => 454, :version => "/conary.rpath.com@rpl:devel//1/20060503-1-0.1"},
      "CherryPy"=>
        {:versionID => 456, :version => "/conary.rpath.com@rpl:devel//1/2.2.1-2-0.1"},
      "TurboJson"=>
        {:versionID => 420, :version => "/conary.rpath.com@rpl:devel//1/0.9a5-1-0.1"},
      "TurboGears"=>
        {:versionID => 458, :version => "/conary.rpath.com@rpl:devel//1/0.9a5-5-0.1"},
      "raa-branding"=>
        {:versionID => 97,
        :version => 
         "/raa.rpath.org@rpath:raa-devel//raa-2//mediawiki.rpath.org@rpl:1/2.0.3-1.0.2-1"},
      "sysfsutils"=>
        {:versionID => 464, :version => "/conary.rpath.com@rpl:devel//1/1.3.0-2-0.1"},
      "sysklogd"=>
        {:versionID => 466, :version => "/conary.rpath.com@rpl:devel//1/1.4.1-8-0.1"},
      "system-config-securitylevel"=>
        {:versionID => 473, :version => "/conary.rpath.com@rpl:devel//1/1.4.22-5.2-1"},
      "sysvinit"=>
        {:versionID => 476, :version => "/conary.rpath.com@rpl:devel//1/2.85-7-0.1"},
      "initscripts"=>
        {:versionID => 478, :version => "/conary.rpath.com@rpl:devel//1/8.12-8.9-1"},
      "chkconfig"=>
        {:versionID => 24, :version => "/conary.rpath.com@rpl:devel//1/1.3.20-11.4-1"},
      "dhclient"=>
        {:versionID => 35, :version => "/conary.rpath.com@rpl:devel//1/3.0.2-2.2-1"},
      "httpd"=>
        {:versionID => 253, :version => "/conary.rpath.com@rpl:devel//1/2.0.59-0.6-1"},
      "kudzu"=>
        {:versionID => 264,
        :version => "/conary.rpath.com@rpl:devel//1/1.1.116.2-3.1-1"},
      "lighttpd"=>
        {:versionID => 283, :version => "/conary.rpath.com@rpl:devel//1/1.4.15-0.1-1"},
      "mediawiki-appliance"=>
        {:versionID => 504, :version => "/vehera-base.rpath.org@rpl:devel/1.6.10-1-1"},
      "mysql-server"=>
        {:versionID => 100, :version => "/conary.rpath.com@rpl:devel//1/5.0.33-1-0.1"},
      "mediawiki"=>
        {:versionID => 511, :version => "/contrib.rpath.org@rpl:devel//1/1.6.10-1.1-1"},
      "raa-backup-mw"=>
        {:versionID => 517, :version => "/mediawiki.rpath.org@rpl:1/1.0-3-1"},
      "nscd"=>
        {:versionID => 142, :version => "/conary.rpath.com@rpl:devel//1/2.3.6-8.7-1"},
      "raa"=>
        {:versionID => 105,
        :version => "/raa.rpath.org@rpath:raa-devel//raa-2/2.0.3-2-1"},
      "raa-lighttpd"=>
        {:versionID => 105,
        :version => "/raa.rpath.org@rpath:raa-devel//raa-2/2.0.3-2-1"},
      "tcp_wrappers"=>
        {:versionID => 520, :version => "/conary.rpath.com@rpl:devel//1/7.6-5-0.1"},
      "openssh-server"=>
        {:versionID => 310, :version => "/conary.rpath.com@rpl:devel//1/4.5p1-0.1-1"},
      "sendmail"=>
        {:versionID => 165, :version => "/conary.rpath.com@rpl:devel//1/8.13.7-0.1-1"},
      "tmpwatch"=>
        {:versionID => 532, :version => "/conary.rpath.com@rpl:devel//1/2.9.3-2-0.1"},
      "tzdata"=>
        {:versionID => 149, :version => "/conary.rpath.com@rpl:devel//1/2007c-3-0.2"},
      "usermode"=>
        {:versionID => 534, :version => "/conary.rpath.com@rpl:devel//1/1.80-3-0.1"},
      "authconfig"=>
        {:versionID => 537, :version => "/conary.rpath.com@rpl:devel//1/4.6.12-8-0.1"},
      "kbd"=>
        {:versionID => 80, :version => "/conary.rpath.com@rpl:devel//1/1.12-10-0.1"},
      "system-config-mouse"=>
        {:versionID => 469, :version => "/conary.rpath.com@rpl:devel//1/1.2.11-3.1-1"},
      "vim-minimal"=>
        {:versionID => 546, :version => "/conary.rpath.com@rpl:devel//1/6.3.90-2.5-1"},
      "vixie-cron"=>
        {:versionID => 549, :version => "/conary.rpath.com@rpl:devel//1/4.1-5.2-1"},
      "w3c-libwww"=>
        {:versionID => 554, :version => "/conary.rpath.com@rpl:devel//1/5.4.0-5-0.1"},
      "ntp"=>
        {:versionID => 106, :version => "/conary.rpath.com@rpl:devel//1/4.2.0-11.3-1"},
      "wireless-tools"=>
        {:versionID => 559, :version => "/conary.rpath.com@rpl:devel//1/27-4-0.1"},
      "rhpl"=>
        {:versionID => 94, :version => "/conary.rpath.com@rpl:devel//1/0.167-4.1-2"},
      "xorg-x11"=>
        {:versionID => 562, :version => "/conary.rpath.com@rpl:devel//1/6.8.2-30.4-1"},
      "ImageMagick"=>
        {:versionID => 33, :version => "/conary.rpath.com@rpl:devel//1/6.2.3.3-3.6-1"},
      "cairo"=>
        {:versionID => 577, :version => "/conary.rpath.com@rpl:devel//1/1.0.2-1-0.1"},
      "pango"=>
        {:versionID => 318, :version => "/conary.rpath.com@rpl:devel//1/1.10.1-1-0.1"},
      "gtk"=>
        {:versionID => 62, :version => "/conary.rpath.com@rpl:devel//1/2.8.6-9.7-1"},
      "GConf"=>
        {:versionID => 17, :version => "/conary.rpath.com@rpl:devel//1/2.12.0-1-0.1"},
      "gnome-vfs"=>
        {:versionID => 60, :version => "/conary.rpath.com@rpl:devel//1/2.12.1.1-3-0.1"},
      "libgnome"=>
        {:versionID => 69, :version => "/conary.rpath.com@rpl:devel//1/2.12.0.1-1-0.1"},
      "libglade"=>
        {:versionID => 76, :version => "/conary.rpath.com@rpl:devel//1/2.5.1-6-0.1"},
      "libgnomecanvas"=>
        {:versionID => 17, :version => "/conary.rpath.com@rpl:devel//1/2.12.0-1-0.1"},
      "libbonoboui"=>
        {:versionID => 73, :version => "/conary.rpath.com@rpl:devel//1/2.10.1-1-0.1"},
      "libgnomeui"=>
        {:versionID => 84, :version => "/conary.rpath.com@rpl:devel//1/2.12.0-3-0.1"},
      "tk"=>
        {:versionID => 527, :version => "/conary.rpath.com@rpl:devel//1/8.4.10-5-0.1"},
      "graphviz"=>
        {:versionID => 48, :version => "/contrib.rpath.org@rpl:devel//1/2.12-2.3-1"},
      "group-amp"=>
        {:versionID => 592, :version => "/vehera-base.rpath.org@rpl:devel/1.6.10-3-1"}
    }
    expect(troves).to eql(expected)
  end
end
