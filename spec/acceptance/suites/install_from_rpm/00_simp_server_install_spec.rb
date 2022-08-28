require 'spec_helper_integration'

test_name 'Install SIMP modules and assets via RPM from internet repos'

# facts gathered here are executed when the file first loads and
# use the facter gem temporarily installed into system ruby
master = only_host_with_role(hosts, 'master')
majver = fact_on(master, 'operatingsystemmajrelease')
osname = fact_on(master, 'operatingsystem')

describe 'Install SIMP modules and assets via RPM from internet repos' do

  context 'all hosts prep' do
    set_up_options = {
      :root_password => test_password(:root),
      :repos         => [
        # SIMP repos **SHOULD** include the necessary puppet + epel RPMs
        :simp,
        :simp_deps
      ]
    }

    hosts.each do |host|
      include_examples 'basic server setup', host, set_up_options
    end
  end

  context 'puppet master prep' do

    # This has to be done **BEFORE** simp config is run and should
    # be done before the simp RPM is installed
    it 'should install puppetserver' do
      install_puppetserver(master)
    end

    it 'should install simp module and asset RPMs and create local Git module repos' do
      master.install_package('simp')
    end
  end

end
