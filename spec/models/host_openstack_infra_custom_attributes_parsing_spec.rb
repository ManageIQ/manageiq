require "spec_helper"

describe ManageIQ::Providers::Openstack::InfraManager::Host do
  #####################################################################
  ##### Variations of nice format  presetn in OpenStack's confs #######
  let(:filesystem_openstack_conf_nice) do
    <<-EOT
[DEFAULT]
# Location of VNC console proxy, in the form
# "http://127.0.0.1:6080/vnc_auto.html" (string value)
# novncproxy_base_url=http://127.0.0.1:6080/vnc_auto.html
novncproxy_base_url=http://0.0.0.0:6089/vnc_auto.html
test=test_value
    EOT
  end

  let(:filesystem_openstack_conf_ignore_header) do
    <<-EOT
[DEFAULT]

# =========Start Global Config Option for Distributed L3 Router===============
# Location of VNC console proxy, in the form
# "http://127.0.0.1:6080/vnc_auto.html" (string value)
# novncproxy_base_url=http://127.0.0.1:6080/vnc_auto.html
novncproxy_base_url=http://0.0.0.0:6089/vnc_auto.html
test=test_value
    EOT
  end

  let(:filesystem_openstack_conf_random_spaces) do
    <<-EOT
  [DEFAULT]

      # Location of VNC console proxy, in the form
# "http://127.0.0.1:6080/vnc_auto.html" (string value)
#         novncproxy_base_url  =http://127.0.0.1:6080/vnc_auto.html
 novncproxy_base_url   =  http://0.0.0.0:6089/vnc_auto.html

   test=test_value
    EOT
  end

  let(:filesystem_openstack_conf_just_default_value) do
    <<-EOT
[DEFAULT]
# Location of VNC console proxy, in the form
# "http://127.0.0.1:6080/vnc_auto.html" (string value)
#novncproxy_base_url=http://127.0.0.1:6080/vnc_auto.html
test=test_value
    EOT
  end

  let(:filesystem_openstack_conf_gets_last_occurrence_of_defined_attr) do
    <<-EOT
[DEFAULT]
# Location of VNC console proxy, in the form
# "http://127.0.0.1:6080/vnc_auto.html" (string value)
# novncproxy_base_url=http://127.0.0.1:6080/vnc_auto.html
novncproxy_base_url=http://0.0.0.0:6089/vnc_auto.html
novncproxy_base_url=http://0.0.0.0:6090/vnc_auto.html
# novncproxy_base_url=http://127.0.0.1:6081/vnc_auto.html
test=test_value
    EOT
  end

  let(:filesystem_openstack_conf_not_supported_colon_as_delimiter) do
    <<-EOT
[DEFAULT]
# Location of VNC console proxy, in the form
# "http://127.0.0.1:6080/vnc_auto.html" (string value)
# novncproxy_base_url=http://127.0.0.1:6080/vnc_auto.html
novncproxy_base_url:http://0.0.0.0:6089/vnc_auto.html
test=test_value
    EOT
  end

  let(:filesystem_openstack_conf_continuation_line) do
    <<-EOT
[DEFAULT]
# Location of VNC console proxy, in the form
# "http://127.0.0.1:6080/vnc_auto.html" (string value)
# novncproxy_base_url=http://127.0.0.1:6080/vnc_auto.html
novncproxy_base_url=http://0.0.0.0:6089/
  vnc_auto.html
test=test_value
    EOT
  end

  let(:filesystem_openstack_conf_commented_attribute_continuation_line) do
    <<-EOT
[DEFAULT]
# Location of VNC console proxy, in the form
# "http://127.0.0.1:6080/vnc_auto.html" (string value)
#novncproxy_base_url=http://127.0.0.1:6080/
# vnc_auto.html

test=test_value
    EOT
  end

  let(:filesystem_openstack_conf_commented_continuation_line) do
    <<-EOT
[DEFAULT]
# Location of VNC console proxy, in the form
# "http://127.0.0.1:6080/vnc_auto.html" (string value)
# novncproxy_base_url=http://127.0.0.1:6080/vnc_auto.html
novncproxy_base_url=http://0.0.0.0:6089/
   #vnc_auto.html
   vnc_auto.html
test=test_value
    EOT
  end

  #########################################
  ##### Variations of interpolation #######
  let(:filesystem_openstack_conf_interpolation_all) do
    <<-EOT
[DEFAULT]

# instances_path=$instances_base_path/${instances_sub_path}

#
# Options defined in nova.virt.libvirt.imagecache
#

instances_base_path=/etc
instances_sub_path=images

image_cache_subdirectory_name = glance
# Allows image information files to be stored in non-standard
# locations (string value)
#image_info_filename_pattern=$instances_path/${image_cache_subdirectory_name}/%(image)s.info
#image=fedora.qcow
# image_cache_subdirectory_name = nova
    EOT
  end

  let(:filesystem_openstack_conf_interpolation_missing_links) do
    <<-EOT
[DEFAULT]
#
# Options defined in nova.virt.libvirt.imagecache
#

# Allows image information files to be stored in non-standard
# locations (string value)
#image_info_filename_pattern=$instances_path/${image_cache_subdirectory_name}/%(image)s.info
    EOT
  end

  let(:filesystem_openstack_conf_interpolation_infinite_cycle) do
    <<-EOT
[DEFAULT]
# Allows image information files to be stored in non-standard
# locations (string value)
#image_info_filename_pattern=$instances_path
#instances_path=$image_info_filename_pattern
    EOT
  end

  #######################################################################################
  ##### Complex formats not preset in Openstack conf files, but defined in parser #######
  # Based on documentation https://docs.python.org/3.4/library/configparser.html
  # and code https://github.com/python/cpython/blob/f5d6573940581019e78b993b048f0641244b208f/Lib/configparser.py#L1013
  let(:filesystem_openstack_conf_complex_example) do
    <<-EOT
   [You can use comments]
# like this

# By default only in an empty line.
# Inline comments can be harmful because they prevent users
# from using the delimiting characters as parts of values.
# That being said, this can be customized.

    [Sections Can Be Indented]
        can_values_be_as_well = True
        does_that_mean_anything_special = False
        purpose = formatting for readability
        multiline_values = are
            handled just fine as
            long as they are indented
            deeper than the first line
            of a value
    not deep enough continuation
        # Did I mention we can indent comments, too?
    EOT
  end

  describe "#refresh_custom_attributes_from_conf_files" do
    let(:host) do
      FactoryGirl.create(:host_openstack_infra).tap do |host|
        host.system_services << FactoryGirl.create(:system_service, :name => 'openstack-nova')
      end
    end

    describe "parse openstack conf nice format" do
      it "parses nice format" do
        files = [FactoryGirl.create(:filesystem_openstack_conf, :contents => filesystem_openstack_conf_nice)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('novncproxy_base_url', standard_nice_format)
        assert_custom_attribute('test', standard_nice_test_format)
        assert_custom_attributes_count(2)
        expect(files.first.custom_attributes.count).to eq 2
      end

      it "ignores headers containing ====" do
        files = [FactoryGirl.create(:filesystem_openstack_conf, :contents => filesystem_openstack_conf_ignore_header)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('novncproxy_base_url', standard_nice_format)
        assert_custom_attribute('test', standard_nice_test_format)
        assert_custom_attributes_count(2)
        expect(files.first.custom_attributes.count).to eq 2
      end

      it "checks random spaces doesn't change the format" do
        files = [FactoryGirl.create(:filesystem_openstack_conf, :contents => filesystem_openstack_conf_random_spaces)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('novncproxy_base_url', standard_nice_format)
        assert_custom_attribute('test', standard_nice_test_format)
        assert_custom_attributes_count(2)
      end

      it "checks that only default value is present" do
        files = [FactoryGirl.create(:filesystem_openstack_conf,
                                    :contents => filesystem_openstack_conf_just_default_value)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('novncproxy_base_url',
                                standard_nice_format(:value              => 'http://127.0.0.1:6080/vnc_auto.html',
                                                     :value_interpolated => 'http://127.0.0.1:6080/vnc_auto.html',
                                                     :source             => 'default'))
        assert_custom_attribute('test', standard_nice_test_format)
        assert_custom_attributes_count(2)
      end

      it "checks that only last defined value is taken" do
        files = [FactoryGirl.create(:filesystem_openstack_conf,
                                    :contents => filesystem_openstack_conf_gets_last_occurrence_of_defined_attr)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('novncproxy_base_url',
                                standard_nice_format(:value              => 'http://0.0.0.0:6090/vnc_auto.html',
                                                     :value_interpolated => 'http://0.0.0.0:6090/vnc_auto.html'))
        assert_custom_attribute('test', standard_nice_test_format)
        assert_custom_attributes_count(2)
      end

      it "check that colon as delimiter is not supported" do
        # !!! This is change of the standard python parser
        files = [FactoryGirl.create(:filesystem_openstack_conf,
                                    :contents => filesystem_openstack_conf_not_supported_colon_as_delimiter)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('novncproxy_base_url',
                                standard_nice_format(:value              => 'http://127.0.0.1:6080/vnc_auto.html',
                                                     :value_interpolated => 'http://127.0.0.1:6080/vnc_auto.html',
                                                     :source             => 'default'))
        assert_custom_attribute('test', standard_nice_test_format)
        assert_custom_attributes_count(2)
      end

      it "check that continuation line of value works" do
        # !!! This is change of the standard python parser
        files = [FactoryGirl.create(:filesystem_openstack_conf,
                                    :contents => filesystem_openstack_conf_continuation_line)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('novncproxy_base_url',
                                standard_nice_format(:value              => "http://0.0.0.0:6089/\nvnc_auto.html",
                                                     :value_interpolated => "http://0.0.0.0:6089/\nvnc_auto.html"))
        assert_custom_attribute('test', standard_nice_test_format)
        assert_custom_attributes_count(2)
      end

      it "check that commented attr doesnt store continuation lines" do
        files = [FactoryGirl.create(:filesystem_openstack_conf,
                                    :contents => filesystem_openstack_conf_commented_attribute_continuation_line)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('novncproxy_base_url',
                                standard_nice_format(:value              => 'http://127.0.0.1:6080/',
                                                     :value_interpolated => 'http://127.0.0.1:6080/',
                                                     :source             => 'default'))
        assert_custom_attribute('test', standard_nice_test_format)
        assert_custom_attributes_count(2)
      end

      it "check that commented continuation line of value is not stored" do
        files = [FactoryGirl.create(:filesystem_openstack_conf,
                                    :contents => filesystem_openstack_conf_commented_continuation_line)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('novncproxy_base_url',
                                standard_nice_format(:value              => "http://0.0.0.0:6089/\nvnc_auto.html",
                                                     :value_interpolated => "http://0.0.0.0:6089/\nvnc_auto.html"))
        assert_custom_attribute('test', standard_nice_test_format)
        assert_custom_attributes_count(2)
      end
    end

    describe "parse interpolated attributes" do
      it "checks all types of interpolation and nested interpolation" do
        files = [FactoryGirl.create(:filesystem_openstack_conf,
                                    :contents => filesystem_openstack_conf_interpolation_all)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('instances_base_path',
                                :section            => 'DEFAULT',
                                :description        => nil,
                                :value              => '/etc',
                                :value_interpolated => '/etc',
                                :source             => 'defined')

        assert_custom_attribute('instances_sub_path',
                                :section            => 'DEFAULT',
                                :description        => nil,
                                :value              => 'images',
                                :value_interpolated => 'images',
                                :source             => 'defined')

        assert_custom_attribute('instances_path',
                                :section            => 'DEFAULT',
                                :description        => nil,
                                :value              => '$instances_base_path/${instances_sub_path}',
                                :value_interpolated => '/etc/images',
                                :source             => 'default')

        assert_custom_attribute('image_cache_subdirectory_name',
                                :section            => 'DEFAULT',
                                :description        => nil,
                                :value              => 'glance',
                                :value_interpolated => 'glance',
                                :source             => 'defined')

        assert_custom_attribute('image_info_filename_pattern',
                                :section            => 'DEFAULT',
                                :description        => "Allows image information files to be stored in non-standard\nlocations (string value)",
                                :value              => '$instances_path/${image_cache_subdirectory_name}/%(image)s.info',
                                :value_interpolated => '/etc/images/glance/fedora.qcows.info',
                                :source             => 'default')

        assert_custom_attribute('image',
                                :section            => 'DEFAULT',
                                :description        => nil,
                                :value              => 'fedora.qcow',
                                :value_interpolated => 'fedora.qcow',
                                :source             => 'default')

        assert_custom_attributes_count(6)
      end

      it "checks not completed interpolation" do
        files = [FactoryGirl.create(:filesystem_openstack_conf,
                                    :contents => filesystem_openstack_conf_interpolation_missing_links)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('image_info_filename_pattern',
                                :section            => 'DEFAULT',
                                :description        => "Allows image information files to be stored in non-standard\nlocations (string value)",
                                :value              => '$instances_path/${image_cache_subdirectory_name}/%(image)s.info',
                                :value_interpolated => '$instances_path/${image_cache_subdirectory_name}/%(image)s.info',
                                :source             => 'default')

        assert_custom_attributes_count(1)
      end

      it "checks cycles in interpolation logs warning and ends" do
        files = [FactoryGirl.create(:filesystem_openstack_conf,
                                    :contents => filesystem_openstack_conf_interpolation_infinite_cycle)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('image_info_filename_pattern',
                                :section            => 'DEFAULT',
                                :description        => "Allows image information files to be stored in non-standard\nlocations (string value)",
                                :value              => '$instances_path',
                                :value_interpolated => '$instances_path',
                                :source             => 'default')

        assert_custom_attribute('instances_path',
                                :section            => 'DEFAULT',
                                :description        => nil,
                                :value              => '$image_info_filename_pattern',
                                :value_interpolated => '$image_info_filename_pattern',
                                :source             => 'default')

        assert_custom_attributes_count(2)
      end
    end

    describe "parse complex Python configparser examples" do
      it "parses complex continuation line example" do
        files = [FactoryGirl.create(:filesystem_openstack_conf,
                                    :contents => filesystem_openstack_conf_complex_example)]
        host.refresh_custom_attributes_from_conf_files(files)

        assert_custom_attribute('can_values_be_as_well',
                                :section            => 'Sections Can Be Indented',
                                :description        => nil,
                                :value              => 'True',
                                :value_interpolated => 'True',
                                :source             => 'defined')

        assert_custom_attribute('does_that_mean_anything_special',
                                :section            => 'Sections Can Be Indented',
                                :description        => nil,
                                :value              => 'False',
                                :value_interpolated => 'False',
                                :source             => 'defined')

        assert_custom_attribute('purpose',
                                :section            => 'Sections Can Be Indented',
                                :description        => nil,
                                :value              => 'formatting for readability',
                                :value_interpolated => 'formatting for readability',
                                :source             => 'defined')

        assert_custom_attribute('multiline_values',
                                :section            => 'Sections Can Be Indented',
                                :description        => nil,
                                :value              => "are\nhandled just fine as\nlong as they are indented\ndeeper than the first line\nof a value",
                                :value_interpolated => "are\nhandled just fine as\nlong as they are indented\ndeeper than the first line\nof a value",
                                :source             => 'defined')

        assert_custom_attributes_count(4)
      end
    end
  end

  def assert_custom_attribute(name, attributes)
    expect(CustomAttribute.where(:name => name).first).to have_attributes attributes
  end

  def assert_custom_attributes_count(count)
    expect(CustomAttribute.count).to eq count
  end

  def standard_nice_format(attributes = {})
    {:section            => 'DEFAULT',
     :description        => "Location of VNC console proxy, in the form\n\"http://127.0.0.1:6080/vnc_auto.html\" (string value)",
     :value              => 'http://0.0.0.0:6089/vnc_auto.html',
     :value_interpolated => 'http://0.0.0.0:6089/vnc_auto.html',
     :source             => 'defined'}.merge(attributes)
  end

  def standard_nice_test_format(attributes = {})
    {:section            => 'DEFAULT',
     :description        => nil,
     :value              => 'test_value',
     :value_interpolated => 'test_value',
     :source             => 'defined'}.merge(attributes)
  end
end
