#!/usr/bin/rake -T

require 'simp/rake/pupmod/helpers'
require 'simp/rake/build/deps'

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

def load_modules(puppetfile)
  require 'r10k/puppetfile'

  fail "Could not find file '#{puppetfile}'" unless File.exist?(puppetfile)

  r10k = R10K::Puppetfile.new(Dir.pwd, nil, puppetfile)
  r10k.load!

  modules = {}

  r10k.modules.each do |mod|
    # Skip anything that's not pinned

    next unless mod.instance_variable_get('@args').keys.include?(:tag)

    modules[mod.name] = {
      :id          => mod.name,
      :owner       => mod.owner,
      :path        => mod.path.to_s,
      :remote      => mod.repo.instance_variable_get('@remote'),
      :desired_ref => mod.desired_ref,
      :version     => mod.desired_ref,
      :git_source  => mod.repo.repo.origin,
      :git_ref     => mod.repo.head,
      :module_dir  => mod.basedir,
      :r10k_module => mod,
      :r10k_cache  => mod.repo.repo.cache_repo
    }
  end

  return modules
end

def update_module_github_status!(mod)
  require 'json'
  require 'nokogiri'
  require 'open-uri'

  require 'highline'
  HighLine.colorize_strings

  mod[:published] ||= {}
  mod[:published]['GitHub'] ||= 'unknown'
  mod[:published]['Puppet Forge'] ||= 'unknown'

  # See if we have a valid release on GitHub
  github_releases_url = mod[:remote] + '/releases'

  begin
    github_query = Nokogiri::HTML(open(github_releases_url).read)

    if github_query.xpath('//a/@title').map(&:value).include?(mod[:version])
      mod[:published]['GitHub'] = 'yes'.green
    else
      mod[:published]['GitHub'] = 'no'.red
    end
  rescue
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
end

def update_module_puppet_forge_status!(mod)
  require 'open-uri'

  require 'highline'
  HighLine.colorize_strings

  forge_url_base  = 'https://forgeapi.puppet.com/v3/releases/'

  mod[:published] ||= {}
  mod[:published]['Puppet Forge'] ||= 'unknown'

  unless mod[:published]['Puppet Forge'] == 'N/A'
    begin
      # Now, check the Puppet Forge for the released module
      open(URI.parse(forge_url_base + mod[:owner] + '-' + mod[:id] + '-' + mod[:version])) do |fh|
        mod[:published]['Puppet Forge'] = 'yes'.green
      end
    rescue StandardError => e
      mod[:published]['Puppet Forge'] = 'no'.red
    end
  end
end

def update_module_package_cloud_status!(mod)
  require 'open-uri'
  require 'nokogiri'

  require 'highline'
  HighLine.colorize_strings

  pcloud_url_base = 'https://packagecloud.io/app/simp-project/6_X/search?'

  mod[:published] ||= {}

  ['6','7'].each do |ver|
    mod[:published]["Package Cloud #{ver}"] ||= 'unknown'

    # Finally, check to see if we're published on Package Cloud (as best we can)
    url = pcloud_url_base + 'q='

    unless ['unknown', 'N/A'].include?(mod[:published]['Puppet Forge'])
      url = url + 'pupmod-'
    end

    url = url + mod[:owner] + '-' + mod[:id] + '-' + mod[:version]

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
end

def print_module_status(mod)
  puts "== #{mod[:owner]}-#{mod[:id]} #{mod[:version]} =="
  puts mod[:published].to_a.map{|x,y| "   * #{x} => #{y}"}.join("\n")
end
