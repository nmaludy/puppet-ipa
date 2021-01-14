Facter.add(:ipa_login_defs) do
  confine { File.exist?('/etc/login.defs') }

  setcode do
    regex_login_defs = Regexp.new(%r{^\s*([A-Z_0-9]+)\s+(.+)(\s*#.*)?$})
    lines_array = File.readlines('/etc/login.defs')
    login_defs = {}
    lines_array.each do |line|
      match = line.match(regex_login_defs)
      next unless match
      param = match.captures[0]
      value = match.captures[1]
      # if the string only contains numbers, cast it to a number
      value = value.to_i if value =~ %r{^\d+$}
      login_defs[param] = value
    end
    login_defs
  end
end
