require 'fileutils'

# Runs an OpenSCAP XCCDF evaluation (by default the SCAP Security Guide's
# DISA STIG profile) on each host, copies the results and HTML report back
# to sec_results/openscap/<label>/<host>/, and appends a row with the score
# to sec_results/openscap/summary.md.
#
# The scan is report-only: it fails only if the scan itself cannot run.
#
# options keys:
#   :label   - (REQUIRED) name for this scan, e.g. 'simp-defaults'
#   :profile - (OPTIONAL) XCCDF profile; defaults to BEAKER_openscap_profile
#              or 'stig'
#
# Each host must be able to install openscap-scanner and scap-security-guide
# from its configured repositories.
shared_examples 'OpenSCAP scan' do |hosts_to_scan, options|
  label   = options.fetch(:label)
  profile = options[:profile] || ENV.fetch('BEAKER_openscap_profile', 'stig')
  results_root = File.join('sec_results', 'openscap')

  hosts_to_scan.each do |host|
    context "OpenSCAP '#{profile}' scan of #{host} (#{label})" do
      let(:remote_dir) { "/root/openscap/#{label}" }
      let(:local_dir) { File.join(results_root, label, host.name) }

      it 'installs the OpenSCAP scanner and SCAP Security Guide' do
        # repo_gpgcheck may be on after a STIG profile is enforced, and
        # not every repo signs its metadata
        on(host, 'rpm -q openscap-scanner scap-security-guide || ' \
                 'dnf -y --setopt=repo_gpgcheck=0 install openscap-scanner scap-security-guide')
      end

      it 'scans the host' do
        on(host, "mkdir -p #{remote_dir}")

        # SSG ships one data stream per distribution (e.g. AlmaLinux's
        # package adds ssg-almalinux9-ds.xml); fall back to the RHEL one.
        os_id = on(host, '. /etc/os-release && echo "${ID}"').stdout.strip
        os_maj = on(host, '. /etc/os-release && echo "${VERSION_ID%%.*}"').stdout.strip
        ds_dir = '/usr/share/xml/scap/ssg/content'
        candidates = ["ssg-#{os_id}#{os_maj}-ds.xml", "ssg-rhel#{os_maj}-ds.xml"].map { |f| File.join(ds_dir, f) }
        datastream = candidates.find { |f| on(host, "test -f #{f}", accept_all_exit_codes: true).exit_code.zero? }
        expect(datastream).not_to be_nil, "No SSG data stream found on #{host}; tried #{candidates.join(', ')}"

        on(host, "oscap info --profiles #{datastream} | grep -E '(^|_)#{profile}(:|$)'")

        # oscap exits 2 when any rule fails, which is expected here
        on(host,
           [
             'oscap xccdf eval',
             "--profile #{profile}",
             "--results #{remote_dir}/results.xml",
             "--report #{remote_dir}/report.html",
             datastream,
             "> #{remote_dir}/oscap.log 2>&1",
           ].join(' '),
           acceptable_exit_codes: [0, 2])
        on(host, "echo #{datastream} > #{remote_dir}/datastream")
      end

      it 'copies the results back and records the score' do
        FileUtils.mkdir_p(local_dir)
        %w[results.xml report.html oscap.log datastream].each do |f|
          scp_from(host, "#{remote_dir}/#{f}", local_dir)
        end

        results = File.read(File.join(local_dir, 'results.xml'))
        score = results[%r{<score[^>]*system="urn:xccdf:scoring:default"[^>]*>([\d.]+)</score>}, 1]
        expect(score).not_to be_nil, 'No default XCCDF score in results.xml'

        counts = Hash.new(0)
        results.scan(%r{<rule-result\b.*?<result>(\w+)</result>}m) { |r| counts[r.first] += 1 }

        os = on(host, '. /etc/os-release && echo "${PRETTY_NAME}"').stdout.strip
        datastream = File.basename(File.read(File.join(local_dir, 'datastream')).strip)
        summary = File.join(results_root, 'summary.md')
        unless File.exist?(summary)
          File.write(summary, <<~HEADER)
            | Scan | Host | OS | Data stream | Profile | Score | pass | fail | other |
            |---|---|---|---|---|---|---|---|---|
          HEADER
        end
        other = counts.reject { |k, _| %w[pass fail notselected].include?(k) }.values.sum
        File.open(summary, 'a') do |fh|
          fh.puts "| #{label} | #{host.name} | #{os} | #{datastream} | #{profile} | #{format('%.2f', score.to_f)} | " \
                  "#{counts['pass']} | #{counts['fail']} | #{other} |"
        end
        puts "OpenSCAP #{label} #{host.name}: score #{score}, pass #{counts['pass']}, fail #{counts['fail']}, other #{other}"
      end
    end
  end
end
