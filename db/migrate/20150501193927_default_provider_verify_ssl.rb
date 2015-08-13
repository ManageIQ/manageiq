class DefaultProviderVerifySsl < ActiveRecord::Migration
  class Provider < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time "Setting Provider verify_ssl values for nils" do
      Provider.where(:verify_ssl => nil).update_all(:verify_ssl => OpenSSL::SSL::VERIFY_PEER)
    end
  end

  def down
    # it was ambigious before, no need to set back to nil
  end
end
