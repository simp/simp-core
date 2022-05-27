namespace :puppetfile do
  desc <<-EOM
  Check the deployment status of a specific item from the puppetfile.

  Usage: puppetfile:check_module[<module name>] (exclude the author)
  EOM
  task :check_module, [:module_name, :puppetfile] do |t,args|
    args.with_defaults(:puppetfile => 'tracking')

    fail 'Need a module name' unless args[:module_name]

    base_dir = File.dirname(File.dirname(__FILE__))
    puppetfile = "#{base_dir}/Puppetfile." + args[:puppetfile]

    modules = load_modules(puppetfile)

    target_module = modules.select do |id, mod|
      id == args[:module_name].strip
    end

    if target_module.empty?
      fail "Could not find a tagged version of '#{args[:module_name]}' in '#{puppetfile}'"
    end

    target_module = target_module[target_module.keys.first]

    update_module_github_status!(target_module)
    update_module_puppet_forge_status!(target_module)

    print_module_status(target_module)
  end

  desc <<-EOM
  Check all tagged modules in the Puppetfile and determine if they have been
  published to the Puppet Forge and/or GitHub as appropriate
  EOM
  task :check, [:puppetfile, :local_only] do |t,args|
    # TODO: Add local caching for repeated queries

    args.with_defaults(:puppetfile => 'tracking')
    args.with_defaults(:local_only => 'no')

    local_only = args[:local_only] != 'no'

    base_dir = File.dirname(File.dirname(__FILE__))
    puppetfile = "#{base_dir}/Puppetfile." + args[:puppetfile]

    modules = load_modules(puppetfile)

    modules.each do |id, mod|
      print "Processing: #{mod[:owner]}-#{id}".ljust(55,' ') + "\r"
      $stdout.flush

      unless local_only
        update_module_github_status!(mod)
        update_module_puppet_forge_status!(mod)
      end

      update_module_build_reposync_status!(mod)

      # Be kind, rewind...
      sleep 0.5 unless local_only
    end

    # Return past the status line
    puts ''

    print_module_status(modules)
  end
end
