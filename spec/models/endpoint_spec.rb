RSpec.describe Endpoint do
  let(:endpoint) { FactoryBot.build(:endpoint) }

  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:endpoint, :url => 'thing1')
    expect { m.valid? }.not_to make_database_queries
  end

  describe "#verify_ssl" do
    context "when non set" do
      it "is default to verify ssl" do
        expect(endpoint.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(endpoint).to be_verify_ssl
      end
    end

    context "when set to false" do
      before { endpoint.verify_ssl = false }

      it "is verify none" do
        expect(endpoint.verify_ssl).to eq(OpenSSL::SSL::VERIFY_NONE)
        expect(endpoint).not_to be_verify_ssl
      end
    end

    context "when set to true" do
      before { endpoint.verify_ssl = true }

      it "is verify peer" do
        expect(endpoint.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(endpoint).to be_verify_ssl
      end
    end

    context "when set to verify none" do
      before { endpoint.verify_ssl = OpenSSL::SSL::VERIFY_NONE }

      it "is verify none" do
        expect(endpoint.verify_ssl).to eq(OpenSSL::SSL::VERIFY_NONE)
        expect(endpoint).not_to be_verify_ssl
      end
    end

    context "when set to verify peer" do
      before { endpoint.verify_ssl = OpenSSL::SSL::VERIFY_PEER }

      it "is verify peer" do
        expect(endpoint.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(endpoint).to be_verify_ssl
      end
    end
  end

  context "Uniqueness validation on :url" do
    it "is not required" do
      expect(Endpoint.create!(:url => nil)).to be_truthy
      expect(Endpoint.create!(:url => nil)).to be_truthy
      expect(Endpoint.create!(:url => '')).to be_truthy
      expect(Endpoint.create!(:url => '')).to be_truthy
    end

    it "raises when provided and already exists" do
      Endpoint.create!(:url => "abc")
      expect { Endpoint.create!(:url => "abc") }.to raise_error("Validation failed: Endpoint: Url has already been taken")
    end

    it 'disabled for cloud providers' do
      expect(Endpoint.create!(:url => 'defined', :resource => FactoryBot.create(:ems_cloud))).to be_truthy
      expect(Endpoint.create!(:url => 'defined', :resource => FactoryBot.create(:ems_cloud))).to be_truthy
    end

    it 'enabled for other emses' do
      expect(Endpoint.create!(:url => 'defined', :resource => FactoryBot.create(:ext_management_system))).to be_truthy
      expect { Endpoint.create!(:url => 'defined', :resource => FactoryBot.create(:ext_management_system)) }
        .to raise_error("Validation failed: Endpoint: Url has already been taken")
    end
  end

  context "certificate_authority" do
    # openssl req -x509 -newkey rsa:512 -out cert.pem -nodes, all defaults, twice
    let(:pem1) do
      <<-EOPEM.strip_heredoc
        -----BEGIN CERTIFICATE-----
        MIIBzTCCAXegAwIBAgIJAOgErvCo3YfDMA0GCSqGSIb3DQEBCwUAMEIxCzAJBgNV
        BAYTAlhYMRUwEwYDVQQHDAxEZWZhdWx0IENpdHkxHDAaBgNVBAoME0RlZmF1bHQg
        Q29tcGFueSBMdGQwHhcNMTcwMTE3MTUzODUxWhcNMTcwMjE2MTUzODUxWjBCMQsw
        CQYDVQQGEwJYWDEVMBMGA1UEBwwMRGVmYXVsdCBDaXR5MRwwGgYDVQQKDBNEZWZh
        dWx0IENvbXBhbnkgTHRkMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAKkV4c0cV0oB
        7e1hMmQygmqEELooktNhMpnqqUyy2Lbi/QI3v9f4jyVrI0Uq3x+FXAlopj2ZE+Zp
        qiaq6vmlPSECAwEAAaNQME4wHQYDVR0OBBYEFN6XWVKCGYdjnecoVEt7rtNP4d6S
        MB8GA1UdIwQYMBaAFN6XWVKCGYdjnecoVEt7rtNP4d6SMAwGA1UdEwQFMAMBAf8w
        DQYJKoZIhvcNAQELBQADQQB1IY8KIHcESeKuS8C1i5/wPuFNP3L2a5XKJ29IQsJy
        xY9wgnq7LoIesQsiuiXOGa8L8C9CviIV38Wz9ySt3aLZ
        -----END CERTIFICATE-----
      EOPEM
    end
    let(:pem2) do
      <<-EOPEM.strip_heredoc
        -----BEGIN CERTIFICATE-----
        MIIBzTCCAXegAwIBAgIJAOpKKx6qCHdIMA0GCSqGSIb3DQEBCwUAMEIxCzAJBgNV
        BAYTAlhYMRUwEwYDVQQHDAxEZWZhdWx0IENpdHkxHDAaBgNVBAoME0RlZmF1bHQg
        Q29tcGFueSBMdGQwHhcNMTcwMTE3MTY0ODA3WhcNMTcwMjE2MTY0ODA3WjBCMQsw
        CQYDVQQGEwJYWDEVMBMGA1UEBwwMRGVmYXVsdCBDaXR5MRwwGgYDVQQKDBNEZWZh
        dWx0IENvbXBhbnkgTHRkMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAKVRWFRPhp0g
        XcFcm5sjawbCq8I/segjyEcK/oa547pHJXFeuAi8eq1peVNrXU9mpdvnik1i0aLW
        OuH/XOoUYtUCAwEAAaNQME4wHQYDVR0OBBYEFNpCOxdZrAeWKl1mZRASn4Ss945x
        MB8GA1UdIwQYMBaAFNpCOxdZrAeWKl1mZRASn4Ss945xMAwGA1UdEwQFMAMBAf8w
        DQYJKoZIhvcNAQELBQADQQAuuzLKcHLZDewClpG47ImdMPtupNT0YmOYSnDh/Sge
        tOowLeEkgFb2Eat+n0Ub5BWMuDp0E/d2kx4wMcOLaeLl
        -----END CERTIFICATE-----
      EOPEM
    end

    it "is not required" do
      endpoint.certificate_authority = nil
      expect(endpoint.valid?).to be_truthy
      expect(endpoint.ssl_cert_store).to eq(nil)

      endpoint.certificate_authority = "\n"
      expect(endpoint.valid?).to be_truthy
      expect(endpoint.ssl_cert_store).to eq(nil)
    end

    it "rejects invalid data" do
      endpoint.certificate_authority = "NONSENSE"
      expect(endpoint).not_to be_valid

      endpoint.certificate_authority = <<-EOPEM.strip_heredoc
        -----BEGIN CERTIFICATE-----
        ValidBase64InvalidCert==
        -----END CERTIFICATE-----
      EOPEM
      expect(endpoint).not_to be_valid
    end

    it "ssl_cert_store parses valid cert(s)" do
      endpoint.certificate_authority = pem1
      expect(endpoint).to be_valid
      expect(endpoint.send(:parse_certificate_authority).size).to eq(1)
      expect(endpoint.ssl_cert_store).to be_a(OpenSSL::X509::Store)

      endpoint.certificate_authority = pem1 + pem2
      expect(endpoint).to be_valid
      expect(endpoint.send(:parse_certificate_authority).size).to eq(2)
      expect(endpoint.ssl_cert_store).to be_a(OpenSSL::X509::Store)
    end
  end

  context "to_s" do
    it "returns the url if set" do
      endpoint.url = 'https://www.foo.bar'
      expect(endpoint.to_s).to eql('https://www.foo.bar')
    end

    it "returns a blank string if the url is not set" do
      expect(endpoint.to_s).to eql('')
    end
  end
end
