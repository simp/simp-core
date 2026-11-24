#!/usr/bin/rake -T

require 'naturally'
require 'simp/rake/pupmod/helpers'
require 'simp/rake/pupmod/module_build'
require 'simp/rake/build/deps'

Simp::Rake::Beaker.new(File.dirname(__FILE__))

require 'simp/rake/build/helpers'
BASEDIR = File.dirname(__FILE__)
Simp::Rake::Build::Helpers.new(BASEDIR)

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

# GET a GitHub REST API path and return the parsed JSON, or nil on a 404.
#
# Set GITHUB_TOKEN: the unauthenticated limit (60 requests/hour) is too low
# for a full Puppetfile. Network and 5xx errors are retried; anything else
# raises, so the caller can report 'error' instead of a wrong answer.
def github_api_get(path, attempts: 3)
  require 'json'
  require 'net/http'

  uri = URI("https://api.github.com#{path}")
  attempt = 0
  begin
    attempt += 1
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/vnd.github+json'
    request['X-GitHub-Api-Version'] = '2022-11-28'
    token = ENV['GITHUB_TOKEN'].to_s
    request['Authorization'] = "Bearer #{token}" unless token.empty?

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    raise Net::HTTPFatalError.new("GitHub API returned #{response.code}", response) if response.code.start_with?('5')
    return nil if response.code == '404'
    raise "GitHub API returned #{response.code} for #{uri.path}: #{response.body.to_s[0, 200]}" unless response.code == '200'

    JSON.parse(response.body)
  rescue Net::HTTPFatalError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
    raise "GitHub API request for #{uri.path} failed after #{attempts} attempts: #{e.message}" if attempt >= attempts

    sleep(2 * attempt)
    retry
  end
end

def warn_without_github_token
  return unless ENV['GITHUB_TOKEN'].to_s.empty?

  warn 'WARNING: GITHUB_TOKEN is not set. The unauthenticated GitHub API limit (60 requests/hour)'
  warn '         is too low for a full Puppetfile. Try: GITHUB_TOKEN=$(gh auth token)'
end

def update_module_github_status!(mod)
  require 'json'
  require 'open-uri'

  mod[:published] ||= {}
  mod[:published]['GitHub'] ||= 'unknown'
  mod[:published]['Puppet Forge'] ||= 'unknown'

  mod_remote = mod[:remote].gsub(/\.git$/,'')
  repo = mod_remote.sub(%r{^https://github\.com/}, '')
  tag = mod[:version]

  # See if we have a valid release (or at least a tag) on GitHub
  begin
    if github_api_get("/repos/#{repo}/releases/tags/#{tag}")
      mod[:published]['GitHub'] = 'yes'

      releases = github_api_get("/repos/#{repo}/releases?per_page=100") || []
      latest_version = Naturally.sort(
        releases.reject { |r| r['prerelease'] || r['draft'] }.map { |r| r['tag_name'].gsub(/^\D+/,'') }
      ).last

      if latest_version && latest_version != tag.gsub(/^\D+/,'')
        mod[:published]['GitHub'] = latest_version
      end
    elsif github_api_get("/repos/#{repo}/git/ref/tags/#{tag}")
      mod[:published]['GitHub'] = 'tag'
    else
      mod[:published]['GitHub'] = 'no'
    end
  rescue StandardError => e
    warn "WARNING: #{e.message}"
    mod[:published]['GitHub'] = 'error'
  end

  unless ['no', 'error', nil].include?(mod[:published]['GitHub'])
    to_keep = [
      'GPGKEYS/',
      'SIMP/',
      'bin/',
      'build/',
      'data/',
      'environments/',
      'ext/',
      'files/',
      'functions/',
      'hiera.yaml',
      'lib/',
      'manifests/',
      'metadata.json',
      'rsync/',
      'sbin/',
      'scripts/',
      'share/',
      'src/',
      'tasks/',
      'templates/',
      'types/',
      'utils/'
    ]

    begin
      files = github_api_get("/repos/#{repo}/compare/#{tag}...HEAD")['files'] || []
      diff_items = files.map { |f| f['filename'] }.select { |x| to_keep.find { |k| x.start_with?(k) } }

      if !diff_items.empty?
        mod[:published]['GitHub InSync'] = 'no'
        mod[:published]['GitHub Changed'] = ([''] + diff_items).sort.uniq.join("\n      * ")
      elsif files.length >= 300
        # The compare API lists at most 300 files, so the rest are unknown
        mod[:published]['GitHub InSync'] = 'unknown'
      else
        mod[:published]['GitHub InSync'] = 'yes'
      end
    rescue StandardError => e
      warn "WARNING: #{e.message}"
      mod[:published]['GitHub InSync'] = 'error'
    end
  end

  # See if we're a module and update the version information if necessary
  begin
    URI.open(
      mod_remote.gsub('github.com','raw.githubusercontent.com') +
      '/' +
      mod[:desired_ref] +
      '/' +
      'metadata.json'
    ) do |fh|
      mod_info = JSON.parse(fh.read)

      mod[:version] = mod_info['version']
    end
  rescue StandardError => e
    if e.is_a?(OpenURI::HTTPError) && e.io.status.first == '404'
      # No metadata.json at this ref, so we're not a module
      mod[:published]['Puppet Forge'] = 'N/A'
    else
      warn "WARNING: Could not read metadata.json for #{repo} #{mod[:desired_ref]}: #{e.message}"
    end
  end
end

def update_module_puppet_forge_status!(mod)
  require 'net/http'

  forge_url_base  = 'https://forgeapi.puppet.com/v3/releases/'

  mod[:published] ||= {}
  mod[:published]['Puppet Forge'] ||= 'unknown'

  unless mod[:published]['Puppet Forge'] == 'N/A'
    begin
      # Now, check the Puppet Forge for the released module

      # Switch vox to 'puppet'
      mod_owner = mod[:owner]
      if mod_owner == 'voxpupuli'
        mod_owner = 'puppet'
      end

      response = Net::HTTP.get_response(URI.parse(forge_url_base + mod_owner + '-' + mod[:id] + '-' + mod[:version]))
      mod[:published]['Puppet Forge'] = case response.code
                                        when '200' then 'yes'
                                        when '404' then 'no'
                                        else
                                          warn "WARNING: Puppet Forge returned #{response.code} for #{mod_owner}-#{mod[:id]}-#{mod[:version]}"
                                          'error'
                                        end
    rescue StandardError => e
      warn "WARNING: Puppet Forge check failed for #{mod_owner}-#{mod[:id]}-#{mod[:version]}: #{e.message}"
      mod[:published]['Puppet Forge'] = 'error'
    end
  end
end

def update_module_build_reposync_status!(mod)
  require 'simp/rpm'

  require 'highline'

  local_info = []

  # Switch vox to 'puppet'
  mod_owner = mod[:owner]
  if mod_owner == 'voxpupuli'
    mod_owner = 'puppet'
  end

  rpm_name = 'pupmod-' + mod_owner + '-' + mod[:id]
  rpm_altname = mod[:remote].split('/').last

  Dir.glob('build/distributions/*').each do |distdir|
    local_dist = File.basename(distdir)

    Dir.glob("#{distdir}/*") do |distreldir|
      local_distrel = File.basename(distreldir)

      require 'find'

      Find.find(distreldir) do |syncdir|
        next unless File.directory?(syncdir) && (File.basename(syncdir) == 'reposync')

        simpdir = File.join(syncdir, 'SIMP')
        next unless File.directory?(simpdir)

        Dir.chdir(simpdir) do
          Find.find('.') do |rpm|
            next unless rpm.split('.').last == 'rpm'
            next unless rpm =~ %r{/(#{rpm_name}|#{rpm_altname})-\d.+\.rpm$}

            osrel = "#{local_dist}-#{local_distrel}"
            rpm_info = Simp::RPM.new(File.realpath(rpm))

            output = "#{rpm_info.version} #{osrel}"
            if rpm_info.version == mod[:version].sub(/^v/, '')
              output = "* #{output}"
            else
              output = "! #{output}"
            end

            local_info.push(output)
          end
        end
      end
    end
  end

  if local_info.empty?
    mod[:reposync] = 'unknown'
  else
    mod[:reposync] = "#{local_info.join("\n")}"
  end
end

def print_module_status(target_module)
  require 'terminal-table'

  if target_module[:id]
    to_process = { target_module[:id] => target_module }
  else
    to_process = target_module
  end

  rows = to_process.map{|id, mod|
    [
      "#{mod[:owner]}-#{mod[:id]}",
      mod[:version],
      mod[:published] && mod[:published]['GitHub'],
      mod[:reposync] || '',
      mod[:published] && mod[:published]['GitHub InSync'],
      mod[:published] && mod[:published]['Puppet Forge']
    ]
  }
  table = Terminal::Table.new(
    :headings => ['Name', 'Version', 'GitHub' , 'Reposync', 'GH InSync', 'Forge'],
    :rows => rows
  )

  puts table
end
