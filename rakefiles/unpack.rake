#!/usr/bin/rake -T

desc "Unpack an ISO. Unpacks either a RHEL or CentOS ISO into
<targetdir>/<RHEL|CentOS><version>-<arch>.
 * :iso_path - Full path to the ISO image to unpack.
 * :merge - If true, then automatically merge any existing
   directories. Defaults to prompting.
 * :targetdir - The parent directory for the to-be-created directory
   containing the unpacked ISO. Defaults to the current directory.
 * :isoinfo - The isoinfo executable to use to extract stuff from the ISO.
   Defaults to 'isoinfo'.
 * :os_version - optional override for the <version> number (e.g., '7.0' instead of '7')

"
task :unpack,[:iso_path, :merge, :targetdir, :isoinfo, :os_version] do |t,args|
  args.with_defaults(
    :iso_path   => '',
    :isoinfo    => 'isoinfo',
    :targetdir  => Dir.pwd,
    :merge      => false,
    :os_version => false,
  )

  iso_path   = args.iso_path
  iso_info   = which(args.isoinfo)
  targetdir  = args.targetdir
  merge      = args.merge
  os_version = args.os_version

  # Checking for valid arguments
  File.exist?(args.iso_path) or
    fail "Error: You must provide the full path and filename of the ISO image."

  %x{file #{iso_path}}.split(":")[1..-1].to_s =~ /ISO/ or
    fail "Error: The file provided is not a valid ISO."

  pieces = File.basename(iso_path,'.iso').split('-')

  # Mappings of ISO name to target directory name.
  # This is a hash of hashes to provide room for growth.
  DVD_MAP = {
    # RHEL structure as provided from RHN:
    #   rhel-server-<version>-<arch>-<whatever>
    'rhel' => {
      'baseos'  => 'RHEL',
      'version' => os_version || pieces[2],
      'arch'    => pieces[3]
    },
    # CentOS structure as provided from the CentOS website:
    #   CentOS-<version>-<arch>-<whatever>
    'CentOS' => {
      'baseos'  => 'CentOS',
      'version' => os_version || pieces[1],
      'arch'    => pieces[2]
    }
  }

  # Determine the target directory
  map = DVD_MAP[pieces[0]]
  map.nil? and fail "Error: Could not find a mapping for '#{iso_path}'."
  out_dir = "#{File.expand_path(targetdir)}/#{map['baseos']}#{map['version']}-#{map['arch']}"

  # Attempt a merge
  if File.exist?(out_dir) and merge.to_s.strip == 'false' then
    puts "Directory '#{out_dir}' already exists! Would you like to merge? [Yn]?"
    if not $stdin.gets.strip.match(/^(y.*|$)/i) then
      puts "Skipping #{iso_path}"
      next
    end
  end

  puts "Target dir: #{out_dir}"
  mkdir_p(out_dir)

  # Unpack the ISO
  iso_toc = %x{#{iso_info} -Rf -i #{iso_path}}.split("\n")
  iso_toc.each do |iso_entry|
    iso_toc.delete(File.dirname(iso_entry))
  end

  progress = ProgressBar.create(:title => 'Unpacking', :total => iso_toc.size)

  iso_toc.each do |iso_entry|
    target = "#{out_dir}#{iso_entry}"
    if not File.exist?(target) then
      FileUtils.mkdir_p(File.dirname(target))
      system("#{iso_info} -R -x #{iso_entry} -i #{iso_path} > #{target}")
    end
    if progress then
      progress.increment
    else
      print "#"
    end
  end
end
