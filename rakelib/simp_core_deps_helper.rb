module Simp; end

module Simp::SimpCoreDepsHelper

  # @return changelog difference between the version of a component checked
  #   out in component_dir and prev_version
  #
  # @param component_dir Location of the component checkout
  # @param prev_version  Previous tagged component version or nil
  # @param debug  Whether to log status gathering actions
  #
  def changelog_diff(component_dir, prev_version, debug=false)
    diff = nil
    Dir.chdir(component_dir) do
      if File.exist?('CHANGELOG')
        if prev_version
          cmd = "git diff #{prev_version} CHANGELOG"
        else
          cmd = 'cat CHANGELOG'
        end
        diff = run_cmd(cmd, debug)
      elsif Dir.exist?('build')
        spec_files = Dir.glob('build/*.spec')
        unless spec_files.empty?
          spec_file = spec_files.first
          if prev_version
            cmd = "git diff #{prev_version} #{spec_file}"
          else
            cmd = "cat #{spec_file}"
          end
          specfile_diff = run_cmd(cmd, debug)
          # only want changelog changes in spec file and **assuming**
          # the changelog is the last section in the spec file
          diff = specfile_diff.split('%changelog').last
        end
      end
    end

    if diff.nil?
      diff = "WARNING: Could not find CHANGELOG or RPM spec file in #{component_dir}"
    end

    diff
  end

  # @return Hash of component change info with the following keys:
  #   * :current_version - current version
  #   * :previous_version - previous tagged version or 'N/A'
  #   * :changelog_diff - changelog differences since the previous tagged
  #     version for either CHANGELOG or build/<component>.spec
  #   * :git_log_output - git log entries since the previous tagged version
  #
  # @param component_dir Location of the component checkout at the current
  #   version
  # @param current_version  Current component version
  # @param prev_version  Previous tagged component version or nil
  # @param git_log_opts  Options to be used in the `git log` operation
  # @param debug  Whether to log status gathering actions
  #
  def component_changes(component_dir, current_version, prev_version,
     git_log_opts, debug=false)

    changelog_diff_output = changelog_diff(component_dir, prev_version, debug)
    log_output = ''
    Dir.chdir(component_dir) do
      if prev_version
        log_cmd = "git log #{prev_version}..HEAD #{git_log_opts}"
      else
        log_cmd = "git log #{git_log_opts}"
      end

      log_output = run_cmd(log_cmd, debug)
    end

    {
      :current_version  => current_version,
      :previous_version => ( prev_version.nil? ? 'N/A' : prev_version ),
      :changelog_diff   => changelog_diff_output,
      :git_log_output   => log_output
    }
  end

  # @return Hash of component versions from the Puppetfile.<suffix> for the
  #   simp-core tag <tag>
  #
  # @param tag simp-core tag
  # @param suffix Suffix of the Puppetfile to use to gather the component
  #    information
  # @param debug Whether to log status gathering actions
  #
  # @raise if tag does not exist or Puppetfile specified is not available
  #
  def component_versions_for_tag(tag, suffix, debug=false)
    tags = run_cmd("git tag -l #{tag}", debug)
    unless tags.include?(tag)
      fail("Tag #{tag} not found")
    end

    cmd = "git show #{tag}:Puppetfile.#{suffix}"
    puppetfile_content = run_cmd(cmd, debug)

    unless $? && ($?.exitstatus == 0)
      fail("Puppetfile.#{suffix} not found at #{tag}")
    end

    require 'tmpdir'
    work_dir = Dir.mktmpdir(File.basename(__FILE__))
    component_versions = {}
    Dir.chdir(work_dir) do
      puppetfile = "Puppetfile.#{suffix}.#{tag}"
      FileUtils.rm_f(puppetfile)
      File.open(puppetfile, 'w') { |file| file.puts(puppetfile_content) }
      r10k_helper = R10KHelper.new(puppetfile)
      r10k_helper.modules.collect do |mod|
        component_versions[mod[:name]] = mod[:desired_ref]
      end
    end

    component_versions
  ensure
    FileUtils.remove_entry_secure(work_dir) if work_dir
  end

  # @return Hash of SIMP release changes since the previous simp-core tag
  #   specified in opts.
  #
  #   * Keys are :simp_core, :assets, :modules for the changes for
  #     simp-core itself, Puppetfile components for the src/assets directory,
  #     and Puppetfile components for the src/puppet/modules directory,
  #     respectively
  #   * Each value is a hash containing the component change information.
  #     - Keys are :current_version, :previous_version, :changelog_diff,
  #       and :git_log_output
  #     - For simp-core itself, :changelog_diff contains %changelog differences
  #       in src/assets/simp/build/simp.spec.
  #
  # @param base_dir simp-core base directory with dependencies checked out
  # @param options Hash containing the following keys:
  #   * :prev_tag - simp-core previous version tag
  #   * :prev_suffix - The Puppetfile suffix to use from the previous simp-core tag
  #   * :curr_suffix - The Puppetfile suffix to use from this simp-core checkout
  #   * :brief - whether to only show 1 line git log summaries
  #   * :debug - whether to log status gathering actions
  #
  def gather_changes(base_dir, opts)
    git_log_opts = opts[:brief] ? '--oneline' : ''
    all_changes = { :simp_core => {}, :assets => {}, :modules => {} }

    # gather changes for Puppetfile dependencies
    all_changes[:simp_core]['__SIMP CORE__'] = simp_core_changes(base_dir, opts[:prev_tag],
      git_log_opts, opts[:debug])

    # determine component versions for previous tag
    old_component_versions = component_versions_for_tag(opts[:prev_tag],
      opts[:prev_suffix], opts[:debug])

    # gather changes for Puppetfile dependencies
    Dir.chdir(base_dir) do
      log_output = ''
      r10k_helper = R10KHelper.new("Puppetfile.#{opts[:curr_suffix]}")
      r10k_helper.each_module do |mod|
        if File.directory?(mod[:path])
          next unless simp_component?(mod[:path])

          current_version = "#{mod[:desired_ref]} (#{mod[:git_ref]})"
          prev_version = old_component_versions[mod[:name]]
          unless prev_version == mod[:desired_ref]
            changes = component_changes(mod[:path], current_version,
              prev_version, git_log_opts, opts[:debug])

            if mod[:path].include?('puppet/modules')
              all_changes[:modules][mod[:name]] = changes
            else
              all_changes[:assets][mod[:name]] = changes
            end
          end
        else
          $stderr.puts "WARNING: #{mod[:path]} not found"
        end
      end
    end

    all_changes
  end

  # Log the specified changes to the console
  #
  # @param changes Hash of SIMP release changes since prev_tag
  #
  #   * Keys are :simp_core, :assets, :modules for the changes for
  #     simp-core itself, Puppetfile components for the src/assets directory,
  #     and Puppetfile components for the src/puppet/modules directory,
  #     respectively
  #   * Each value is a hash containing the component change information.
  #     - Keys are :current_version, :previous_version, :changelog_diff,
  #       and :git_log_output
  #     - For simp-core itself, :changelog_diff contains %changelog differences
  #       in src/assets/simp/build/simp.spec.
  #
  # @param prev_tag Previous simp-core tag version used to generate the changes
  #
  def log_changes(changes, prev_tag)
    if ( changes[:simp_core].empty? &&
         changes[:assets].empty? &&
         changes[:modules].empty? )
      puts( "No changes found for any components since SIMP #{prev_tag}")
    else
      require 'pager'
      include Pager
      page

      separator = '='*80
      puts
      puts separator
      puts "Comparison with SIMP #{prev_tag}"
      [:simp_core, :assets, :modules].each do |section|
        changes[section].sort_by { |key| key}.each do |component_name, info|
          puts <<~EOM
            #{separator}
            #{component_name}:
            Current version: #{info[:current_version]}   Previous version: #{info[:previous_version]}
            CHANGELOG diff:
            #{info[:changelog_diff].strip.gsub(/^/,'  ') + "\n"}
            Git Log
            #{info[:git_log_output].strip.gsub(/^/,'  ') + "\n"}
          EOM
        end

        puts
      end
    end
  end

  # Execute a command and return its stdout.
  #
  # Does not check whether the command succeeded and ignores stderr!
  #
  # @param cmd Command to execute
  # @param debug  Whether to log command executed
  #
  def run_cmd(cmd, debug=false)
    puts "In #{Dir.pwd} executing: #{cmd}" if debug
    `#{cmd}`
  end

  # @return true if component in component_dir is a SIMP component
  def simp_component?(component_dir)
    result = false
    metadata_json_file = File.join(component_dir, 'metadata.json')
    if File.exist?(metadata_json_file)
      require 'json'
      metadata = JSON.load(File.read(metadata_json_file))
      result = true if metadata['name'].split('-').first == 'simp'
    else
      build_dir = File.join(component_dir, 'build')
      if Dir.exist?(build_dir)
        spec_files = Dir.glob("#{build_dir}/*.spec")
        result = true if spec_files.size == 1
      end
    end

    result
  end

  # @return Hash of simp-core change info with the following keys:
  #   * :current_version - current version
  #   * :previous_version - previous tagged version
  #   * :changelog_diff - src/assets/simp/build/simp.spec %changelog
  #     differences since the previous tagged version
  #   * :git_log_output - git log entries since the previous tagged version
  #
  # @param base_dir simp-core base directory
  # @param prev_tag  Previous simp-core tagged version
  # @param git_log_opts  Options to be used in the `git log` operation
  # @param debug  Whether to log status gathering actions
  #
  def simp_core_changes(base_dir, prev_tag, git_log_opts, debug)
    simp_dir = File.join(base_dir, 'src', 'assets', 'simp')
    changelog_diff_output = changelog_diff(simp_dir, prev_tag, debug)
    current_version = ''
    log_output = ''
    Dir.chdir(base_dir) do
      # determine simp-core version
      status_output = run_cmd('git status', debug)
      match = status_output.match(/On branch (\S+)/i)
      if match
        git_ref = run_cmd('git log -n 1 --pretty="%H"', debug).strip
        current_version = "#{match[1]} (#{git_ref})"
      else
        match = status_output.match(/HEAD detached at (\S+)/i)
        if match
          current_version = match[1]
        else
          current_version = run_cmd('git log -n 1 --pretty="%H"', debug).strip
        end
      end

      cmd = "git log #{prev_tag}..HEAD #{git_log_opts}"
      log_output = run_cmd(cmd, debug)
    end

    {
      :current_version  => current_version,
      :previous_version => prev_tag,
      :changelog_diff   => changelog_diff_output,
      :git_log_output   => log_output
    }
  end
end
