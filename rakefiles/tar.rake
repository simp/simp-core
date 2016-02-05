#!/usr/bin/rake -T

require 'simp/rake'
include Simp::Rake

namespace :tar do

  directory "#{DVD_DIR}/staging"

  def get_simp_version
    simp_rpm = Dir.glob("#{BASEDIR}/build/SIMP/RPMS/*/simp-[0-9]*.rpm").max_by {|f| File.mtime(f)}
    fail("Could not find simp main RPM in output directory!") unless simp_rpm
    simp_version = File.basename(simp_rpm).gsub(".noarch.rpm","").gsub("simp-","")

    return simp_version
  end

  ##############################################################################
  # Main tasks
  ##############################################################################

  desc <<-EOM
    Build the DVD tarball(s).

      * :chroot - The mock chroot to use for pkg:build
      * :key - What key to use for signing the RPMs
      * :docs - Whether or not to build the documentation
      * :snapshot_release - Append the timestamp to the SIMP tarball(s)
  EOM
  task :build,[:chroot,:key,:docs,:snapshot_release] => ['pkg:build','pkg:checksig'] do |t,args|
    args.with_defaults(:docs => 'true')

    validate_in_mock_group?

    Parallel.map(
      TARGET_DISTS,
      :in_processes => get_cpu_limit,
      :process => t.name
    ) do |dist|
      base_dir = "#{DVD_DIR}/#{dist}/staging"
      destdir = "#{base_dir}/SIMP"

      # Build the staging area
      mkdir_p(destdir)
      Simp::RPM.copy_wo_vcs(DVD_SRC,".",base_dir)

      # Copy in the GPG Public Keys
      mkdir_p("#{destdir}/GPGKEYS")
      ln(Dir.glob("#{BUILD_DIR}/GPGKEYS/RPM-GPG-KEY*"), "#{destdir}/GPGKEYS", :force => true)

      # Copy in the auto-build RPMs
      Dir.chdir("#{BUILD_DIR}/SIMP/RPMS") do
        Dir.glob('*').each do |type|
          dest_type = type
          if File.directory?(type) then
            if type =~ /i.*86/ then
              dest_type = 'i386'
            end

            mkdir_p("#{destdir}/#{dest_type}")
            Dir.chdir(type) do
              ln(Dir.glob("*.#{type}.rpm"),"#{destdir}/#{dest_type}", :force => true)
            end
          end
        end
      end

      if args.docs.casecmp('true') == 0 then
        # Finally, the PDF docs if they exist.
        pdfs = Dir.glob("#{SRC_DIR}/doc/pdf/*")
        if ! pdfs.empty? then
          pdfs.each do |pdf|
            cp(pdf,base_dir)
          end
        else
          # If we don't have PDFs in the directory, yank them out of the
          # RPM itself!
          simp_doc_rpm = Dir.glob("#{BUILD_DIR}/SIMP/RPMS/*/simp-doc*.rpm").last
          if not simp_doc_rpm then
            raise(Exception,"Error: Could not find simp-doc*.rpm in the build, something went very wrong")
          end

          Dir.mktmpdir { |dir|
            Dir.chdir(dir) do
              %x{rpm2cpio #{simp_doc_rpm} | cpio -u --quiet --warning none -ivd ./usr/share/doc/simp-*/pdf/SIMP*.pdf 2>&1 > /dev/null}
              pdf_docs = Dir.glob("usr/share/doc/simp-*/pdf/*.pdf")

              if pdf_docs.empty? then
                raise(Exception,"Error: Could not find any PDFs in the simp-doc RPM, aborting.")
              end

              pdf_docs.each do |pdf|
                cp(pdf,base_dir)
              end
            end
          }
        end
      end
    end

    #Seeing race conditions when this is parallelized.
    @simp_tarballs = {}
    TARGET_DISTS.each do |dist|
      base_dir = "#{DVD_DIR}/#{dist}/staging"
      dvd_name = [ 'SIMP', 'DVD', dist, get_simp_version ]
      dvd_tarball = "#{dvd_name.join('-')}.tar.gz"
      Dir.chdir(base_dir) do
        sh %{tar --owner 0 --group 0 --exclude-vcs --mode=u=rwX,g=rX,o=rX -cpzf "../#{dvd_tarball}" ./*}
        mv("../#{dvd_tarball}",DVD_DIR)
      end

      puts "Package DVD: #{DVD_DIR}/#{dvd_tarball}"
      @simp_tarballs[dist] = "#{DVD_DIR}/#{dvd_tarball}"
      rm_rf(base_dir)
    end
  end
end
