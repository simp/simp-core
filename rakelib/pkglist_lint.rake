require 'tempfile'

namespace :check do

  desc <<~DESC
    Lint sort -uV order of *-simp_pkglist.txt files

    (Excludes comments and whitespace)
  DESC
  task :pkglist_lint do
    base_dir = File.dirname(File.dirname(__FILE__))
    files=%x[find #{base_dir}/build/distributions/*/?/*/DVD -type f -name '*-simp_pkglist.txt'].split("\n")
    problems_found=false

    files.each do |file|
      begin
        active_lines_file = Tempfile.new("#{File.basename(file,'.txt')}-active-lines.txt")
        sort_uv_file       = Tempfile.new("#{File.basename(file,'.txt')}-sort-uV-lines.txt")

        contents = File.open(file).read.split("\n").grep(/^[^#]/).compact
        active_lines_file.write(contents.join("\n")+"\n")
        active_lines_file.flush

        sort_uv_contents = %x[sort -uV #{active_lines_file.path}].split("\n").compact
        sort_uv_file.write(sort_uv_contents.join("\n")+"\n")
        sort_uv_file.flush

        output = %x[diff -c1 --label ': original order' --label ': `sort -uV` order' \
          '#{active_lines_file.path}' '#{sort_uv_file.path}']
        unless $?.success?
          warn "\n== pkglist_lint: ERROR: Lines are not in `sort -uV` order!\n\n"
          warn "   #{file}:\n\n", output.gsub(/^/,'   ')
          problems_found = true
        end
      ensure
        [active_lines_file, sort_uv_file].each do |f|
          f.close
          f.unlink
        end
      end
      exit 1 if problems_found
    end
  end
end
