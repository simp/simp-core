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
    update_module_package_cloud_status!(target_module)

    print_module_status(target_module)
  end

  desc <<-EOM
  Check all tagged modules in the Puppetfile and determine if they have been
  published to the Puppet Forge, GitHub, and/or Package Cloud as appropriate
  EOM
  task :check, [:puppetfile] do |t,args|
    # TODO: Add local caching for repeated queries

    args.with_defaults(:puppetfile => 'tracking')

    base_dir = File.dirname(File.dirname(__FILE__))
    puppetfile = "#{base_dir}/Puppetfile." + args[:puppetfile]

    modules = load_modules(puppetfile)

    modules.each do |id, mod|
      print "Processing: #{mod[:owner]}-#{id}".ljust(55,' ') + "\r"
      $stdout.flush

      update_module_github_status!(mod)
      update_module_puppet_forge_status!(mod)
      update_module_package_cloud_status!(mod)

      # Be kind, rewind...
      sleep 0.5
    end

    # Return past the status line
    puts ''

    modules.each do |id, mod|
      print_module_status(mod)
    end
  end
end
