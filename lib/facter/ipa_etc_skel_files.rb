Facter.add(:ipa_etc_skel_files) do
  confine { File.exist?('/etc/skel') }

  setcode do
    require 'find'
    base_dir = '/etc/skel'
    files = Find.find(base_dir).select { |path| path != base_dir }
    files_hash = {}
    files.each do |path|
      type = File.directory?(path) ? 'directory' : 'file'
      files_hash[path] = {
        ensure: type,
        local_path: path.gsub(base_dir, ''),
      }
    end
    files_hash
  end
end
