require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::YumRepositories < ActionItem

    attr_accessor :www_yum_dir, :yum_repos_d, :yaml_file
    def initialize
      super
      @key         = 'yum::repositories'
      @description = %Q{Sets up the yum repositores for SIMP on apply. (apply-only; noop)}
      @www_yum_dir = File.exists?( '/srv/www/yum/') ? '/srv/www/yum' : '/var/www/yum'
      @yum_repos_d = '/etc/yum.repos.d'
      @yaml_file   = '/etc/puppet/environments/production/hieradata/hosts/puppet.your.domain.yaml'
    end

    def apply
      result = true

      # set up yum repos
      say_green 'Updating YUM Updates Repositories (NOTE: This may take some time)' if !@silent
      yumpath = File.join( @www_yum_dir,
                           Facter.value('operatingsystem'),
                           Facter.value('operatingsystemrelease'),
                           Facter.value('architecture')
                         )
      begin
        Dir.chdir(yumpath) do
          FileUtils.mkdir('Updates') unless File.directory?('Updates')
          Dir.chdir('Updates') do
            system( %q(find . -type f -name '*.rpm' -exec ln -sf {} \\;) )
            cmd = 'createrepo -qqq -p --update .'
            if @silent
              cmd << ' &> /dev/null'
            else
              puts cmd
            end
            system(cmd)
            raise RuntimeError "'#{cmd}' failed in #{Dir.pwd}" unless ($?.nil? || $?.success?)
          end
        end
        system("chown -R root:apache #{@www_yum_dir}/ #{ '&> /dev/null' if @silent }")
        system("chmod -R u=rwX,g=rX,o-rwx #{@www_yum_dir}/")
        raise RuntimeError, "chmod -R u=rwX,g=rX,o-rwx #{@www_yum_dir}/ failed!"  unless ($?.nil? || $?.success?)
        say_green "Finished configuring Updates repository at #{yumpath}/Updates" if !@silent
      rescue => err
        say_red "ERROR: Something went wrong setting up the Updates repo in #{yumpath}!"
        say_red '       Please make sure your Updates repo is properly configured.'
        say_red "\nError output:\n  #{err.class}\n\n  #{err}"
        result = false
      end

      # disable any CentOS repo spam
      Dir.chdir( @yum_repos_d ) do
        if ! Dir.glob('CentOS*.repo').empty?
          `grep "\\[*\\]" *CentOS*.repo | cut -d "[" -f2 | cut -d "]" -f1 | xargs yum-config-manager --disable`
        end

        # enable 'simp::yum::enable_simp_repos' in hosts/puppet.your.domain.yaml
        if ! File.exist?('filesystem.repo')
          cmd = %Q{sed -i '/simp::yum::enable_simp_repos : false/ c\\simp::yum::enable_simp_repos : true' #{@yaml_file}}
          puts cmd if !@silent
          %x{#{cmd}}
          result = result && ($?.nil? || $?.success?)
        end
      end

      result
    end
  end
end
