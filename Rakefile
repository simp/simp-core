#!/usr/bin/rake -T

require 'simp/rake/pupmod/helpers'

Simp::Rake::Beaker.new(File.dirname(__FILE__))

begin
  require 'simp/rake/build/helpers'
  BASEDIR    = File.dirname(__FILE__)
  Simp::Rake::Build::Helpers.new( BASEDIR )
rescue LoadError => e
  warn "WARNING: #{e.message}"
end

task :metadata_lint do
  sh 'metadata-json-lint --strict-dependencies --strict-license --fail-on-warnings metadata.json'
end

task :default do
  help
end

namespace :deps do
  desc <<-EOM
  Remove all checked-out dependency repos

  Uses specified Puppetfile to identify the checked-out repos.

  Arguments:
    * :suffix       => The Puppetfile suffix to use (Default => 'tracking')
    * :remove_cache => Whether to remove the R10K cache after removing the
                       checked-out repos (Default => false)
  EOM
  task :clean, [:suffix,:remove_cache] do |t,args|
    args.with_defaults(:suffix => 'tracking')
    args.with_defaults(:remove_cache => false)
    base_dir = File.dirname(__FILE__)

    r10k_helper = R10KHelper.new("Puppetfile.#{args[:suffix]}")

    r10k_issues = Parallel.map(
      Array(r10k_helper.modules),
        :in_processes => get_cpu_limit,
        :progress => 'Dependency Removal'
    ) do |mod|
      Dir.chdir(base_dir) do
        FileUtils.rm_rf(mod[:path])
      end
    end

    if args[:remove_cache]
      cache_dir = File.join(base_dir, '.r10k_cache')
      FileUtils.rm_rf(cache_dir)
    end
  end
end

namespace :pkg do
  desc <<-EOM
  Remove all built artifacts in build/

  Arguments:
    * :remove_yum_cache   => Whether to remove the yum cache (Default => true)
    * :remove_dev_gpgkeys => Whether to remove the SIMP Dev GPG keys (Default => true)
  EOM
  task :build_clean, [:remove_yum_cache,:remove_dev_gpgkeys] do |t,args|
    args.with_defaults(:remove_yum_cache => 'true')
    args.with_defaults(:remove_dev_gpgkeys => 'true')

    base_dir = File.dirname(__FILE__)
    #                                                          OS   ver  arch
    distr_glob = File.join(base_dir, 'build', 'distributions', '*', '*', '*')

    dirs_to_remove = [
      Dir.glob(File.join(distr_glob, 'SIMP*')),
      Dir.glob(File.join(distr_glob, 'DVD_Overlay'))
    ]

    if args[:remove_yum_cache] == 'true'
      dirs_to_remove += Dir.glob(File.join(distr_glob, 'yum_data', 'packages'))
    end

    if args[:remove_dev_gpgkeys] == 'true'
      dirs_to_remove += Dir.glob(File.join(distr_glob, 'build_keys', 'dev'))
      dirs_to_remove += Dir.glob(File.join(distr_glob, 'DVD', 'RPM-GPG-KEY-SIMP-Dev'))
    end
    dirs_to_remove.flatten.each { |dir| FileUtils.rm_rf(dir, :verbose =>true) }
  end
end

namespace :puppetfile do
  desc <<-EOM
  Check all tagged modules in the Puppetfile and determine if they have been
  published to the Puppet Forge, GitHub, and/or Package Cloud as appropriate
  EOM
  task :check, [:puppetfile] do |t,args|
    # TODO: Add local caching for repeated queries

    FORGE_URL_BASE  = 'https://forgeapi.puppet.com/v3/releases/'
    PCLOUD_URL_BASE = 'https://packagecloud.io/app/simp-project/6_X/search?'

    require 'highline'
    require 'json'
    require 'nokogiri'
    require 'open-uri'
    require 'r10k/puppetfile'

    HighLine.colorize_strings

    args.with_defaults(:puppetfile => 'tracking')

    puppetfile = 'Puppetfile.' + args[:puppetfile]

    fail "Could not find file '#{puppetfile}'" unless File.exist?(puppetfile)

    r10k = R10K::Puppetfile.new(Dir.pwd, nil, puppetfile)
    r10k.load!

    modules = {}

    r10k.modules.each do |mod|
      # Skip anything that's not pinned

      next unless mod.instance_variable_get('@args').keys.include?(:tag)

      modules[mod.name] = {
        :owner       => mod.owner,
        :path        => mod.path.to_s,
        :remote      => mod.repo.instance_variable_get('@remote'),
        :desired_ref => mod.desired_ref,
        :version     => mod.desired_ref,
        :git_source  => mod.repo.repo.origin,
        :git_ref     => mod.repo.head,
        :module_dir  => mod.basedir,
        :r10k_module => mod,
        :r10k_cache  => mod.repo.repo.cache_repo,
        :published   => {
          'GitHub'          => 'unknown',
          'Puppet Forge'    => 'unknown',
          'Package Cloud 6' => 'unknown',
          'Package Cloud 7' => 'unknown'
        }
      }
    end

    modules.each do |id, mod|
      print "Processing: #{mod[:owner]}-#{id}".ljust(55,' ') + "\r"
      $stdout.flush

      # First, we need to see if we have a valid release on GitHub
      github_releases_url = URI.parse(mod[:remote] + '/releases/tag/' + mod[:desired_ref])

      github_releases_req = Net::HTTP.new(github_releases_url.host, github_releases_url.port)
      github_releases_req.use_ssl = true

      github_releases_res = github_releases_req.request_head(github_releases_url.path)

      if github_releases_res.code == '200'
        mod[:published]['GitHub'] = 'yes'.green
      else
        mod[:published]['GitHub'] = 'no'.red
      end

      # See if we're a module and update the version information if necessary
      begin
        open(
          mod[:remote].gsub('github.com','raw.githubusercontent.com') +
          '/' +
          mod[:desired_ref] +
          '/' +
          'metadata.json'
        ) do |fh|
          mod_info = JSON.parse(fh.read)

          mod[:version] = mod_info['version']
        end
      rescue StandardError => e
        # If we get here, we're not a module
        mod[:published]['Puppet Forge'] = 'N/A'
      end

      unless mod[:published]['Puppet forge'] == 'N/A'
        begin
          # Now, check the Puppet Forge for the released module
          open(URI.parse(FORGE_URL_BASE + mod[:owner] + '-' + id + '-' + mod[:version])) do |fh|
            mod[:published]['Puppet Forge'] = 'yes'.green
          end
        rescue StandardError => e
          mod[:published]['Puppet Forge'] = 'no'.red
        end
      end

      ['6','7'].each do |ver|
        # Finally, check to see if we're published on Package Cloud (as best we can)
        url = PCLOUD_URL_BASE + 'q='

        if mod[:published]['Puppet Forge'] == 'yes'
          url = url + 'pupmod-'
        end

        url = url + mod[:owner] + '-' + id + '-' + mod[:version]

        url = url + "&dist=el/#{ver}"

        begin
          package_cloud_query = Nokogiri::HTML(open(url).read)

          pkg_info = package_cloud_query.xpath("//*[contains(@class, 'package-info-details')]")

          if pkg_info.empty?
            mod[:published]["Package Cloud #{ver}"] = 'no'.red
          else
            mod[:published]["Package Cloud #{ver}"] = pkg_info.css('a').first.text.green
          end
        rescue StandardError => e
          mod[:published]["Package Cloud #{ver}"] = 'no'.red
        end
      end

      # Be kind, rewind...
      sleep 0.5
    end

    # Return past the status line
    puts ''

    modules.each do |id, mod|
      puts "#{mod[:owner]}-#{id} #{mod[:version]}".bold
      puts mod[:published].to_a.map{|x,y| "  * #{x} => #{y}"}.join("\n")
    end
  end
end
