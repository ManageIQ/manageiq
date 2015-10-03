require "spec_helper"
require_migration

describe AddContainerImageDigest do
  let(:container_image_stub) { migration_stub(:ContainerImage) }

  ROW_ENTRIES = [
    {:tag_in => 'sha256',     :tag_out => 'sha256',    :digest  => nil},
    {:tag_in => 'sha384',     :tag_out => 'sha384',    :digest  => nil},
    {:tag_in => 'sha512',     :tag_out => 'sha512',    :digest  => nil},
    {:tag_in => 'sha256abc',  :tag_out => 'sha256abc', :digest  => nil},
    {:tag_in => 'sha384abc',  :tag_out => 'sha384abc', :digest  => nil},
    {:tag_in => 'sha512abc',  :tag_out => 'sha512abc', :digest  => nil},
    {:tag_in => 'sha256:abc', :tag_out => nil,         :digest  => 'sha256:abc'},
    {:tag_in => 'sha384:abc', :tag_out => nil,         :digest  => 'sha384:abc'},
    {:tag_in => 'sha512:abc', :tag_out => nil,         :digest  => 'sha512:abc'}
  ]

  migration_context :up do
    it "migrates a series of representative row" do
      ROW_ENTRIES.each do |x|
        x[:image] = container_image_stub.create!(:tag => x[:tag_in])
      end

      migrate

      ROW_ENTRIES.each do |x|
        expect(x[:image].reload).to have_attributes(
          :tag    => x[:tag_out],
          :digest => x[:digest]
        )
      end
    end
  end

  migration_context :down do
    it "migrates a series of representative row" do
      ROW_ENTRIES.each do |x|
        x[:image] = container_image_stub.create!(
          :tag    => x[:tag_out],
          :digest => x[:digest]
        )
      end

      migrate

      ROW_ENTRIES.each do |x|
        expect(x[:image].reload).to have_attributes(:tag => x[:tag_in])
      end
    end
  end
end
