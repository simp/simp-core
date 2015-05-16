require 'simp/cli/config/utils'
require 'rspec/its'
require_relative 'spec_helper'

describe Simp::Cli::Config::Utils do
  describe ".validate_fqdn" do
    it "validates good FQDNs" do
      expect( Simp::Cli::Config::Utils.validate_fqdn 'simp.dev' ).to eq true
      expect( Simp::Cli::Config::Utils.validate_fqdn 'si-mp.dev' ).to eq true

      # RFC 1123 permits hostname labels to start with digits (overriding RFC 952)
      expect( Simp::Cli::Config::Utils.validate_fqdn '0simp.dev' ).to eq true
    end

    it "doesn't validate bad FQDNS" do
      expect( Simp::Cli::Config::Utils.validate_fqdn '.simp.dev' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn 'simp.dev.' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn '-simp.dev' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_fqdn 'simp.dev-' ).to eq false
    end
  end


  describe ".validate_ip" do
    it "validates good IPs" do
      expect( Simp::Cli::Config::Utils.validate_ip '192.168.1.1' ).to eq true
    end

    it "doesn't validate bad IPS" do
      expect( Simp::Cli::Config::Utils.validate_ip 0 ).to            eq false
      expect( Simp::Cli::Config::Utils.validate_ip false ).to        eq false
      expect( Simp::Cli::Config::Utils.validate_ip nil ).to          eq false
      expect( Simp::Cli::Config::Utils.validate_ip 'zombo.com' ).to  eq false
      expect( Simp::Cli::Config::Utils.validate_ip '1.2.3' ).to      eq false
      expect( Simp::Cli::Config::Utils.validate_ip '1.2.3.999' ).to  eq false
      expect( Simp::Cli::Config::Utils.validate_ip '8.8.8.8.' ).to   eq false
      expect( Simp::Cli::Config::Utils.validate_ip '1.2.3.4.5' ).to  eq false
      expect( Simp::Cli::Config::Utils.validate_ip '1.2.3.4/24' ).to eq false
    end
  end


  describe ".validate_hostname" do
    it "validates good hostnames" do
      expect( Simp::Cli::Config::Utils.validate_hostname 'log' ).to        eq true
      expect( Simp::Cli::Config::Utils.validate_hostname 'log-server' ).to eq true

      # RFC 1123 permits hostname labels to start with digits (overriding RFC 952)
      expect( Simp::Cli::Config::Utils.validate_hostname '0log' ).to eq true
    end

    it "doesn't validate bad hostnames" do
      expect( Simp::Cli::Config::Utils.validate_hostname 'log-' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_hostname 'log.' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_hostname '-log' ).to eq false

      # longer than 63 chars
      expect( Simp::Cli::Config::Utils.validate_hostname \
            'log0234567891234567890223456789323456789423456789523456789623459'
      ).to eq false
    end
  end


  describe ".validate_hiera_lookup" do
    it "validates correct hiera lookup syntax" do
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup "%{hiera('puppet::ca')}" ).to eq true
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup "%{::domain}" ).to eq true
    end

    it "validates correct hiera lookup syntax" do
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup "%[hiera('puppet::ca')]" ).to eq false
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup '' ).to    eq false
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup 'foo' ).to eq false
      expect( Simp::Cli::Config::Utils.validate_hiera_lookup nil).to    eq false
    end
  end


  describe ".validate_password" do
    it "validates good passwords" do
      expect( Simp::Cli::Config::Utils.validate_password 'dup3rP@ssw0r!x' ).to eq true
    end

    it "raises an PasswordError on short passwords" do
      expect{ Simp::Cli::Config::Utils.validate_password 'a@1X' }.to raise_error( Simp::Cli::Config::PasswordError )
    end

    it "raises an PasswordError on simple passwords" do
      expect{ Simp::Cli::Config::Utils.validate_password 'aaaaaaaaaaaaaaa' }.to raise_error( Simp::Cli::Config::PasswordError )
    end
  end


  describe ".generate_password" do
    it "is the correct length" do
      expect( Simp::Cli::Config::Utils.generate_password.size ).to eq 32
      expect( Simp::Cli::Config::Utils.generate_password( 73 ).size ).to eq 73
    end

    it "does not start or end with a special character" do
      expect( Simp::Cli::Config::Utils.generate_password ).to_not match /^[#%&_.:@-]|[#%&_.:@-]$/
    end
  end


  describe ".encrypt_openldap_hash" do
    it "encrypts a known password and salt to the correct SHA-1 password hash" do
      expect( Simp::Cli::Config::Utils.encrypt_openldap_hash \
        'foo', "\xef\xb2\x2e\xac"
      ).to eq '{SSHA}zxOLQEdncCJTMObl5s+y1N/Ydh3vsi6s'
    end
  end


  describe ".validate_openldap_hash" do
    it "validates OpenLDAP-format SHA-1 algorithm (FIPS 160-1) password hash" do
      expect( Simp::Cli::Config::Utils.validate_openldap_hash  \
        '{SSHA}Y6x92VpatHf9G6yMiktUYTrA/3SxUFm'
      ).to eq true
    end
  end


  describe ".generate_certificates" do
    it "runs './gencerts_nopass.sh auto' in the FakeCA dir" do
      # TODO: scaffold a FakeCA dir, cacertkey, and ./gencerts_nopass.sh?
      skip 'How should we test this?'
    end
  end
end
