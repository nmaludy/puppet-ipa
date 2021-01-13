Facter.add(:ipa_login_defs) do
  confine { File.exist?('/etc/login.defs') }

  setcode do
    regex_login_defs = Regexp.new(%r{^\s*([A-Z_0-9]+)\s+(\d+)(\s*#.*)?$})
    lines_array = File.readlines('/etc/login.defs')
    login_defs = {}
    lines_array.each do |line|
      if (match = line.match(regex_login_defs))
        param = match.captures[0]
        value = match.captures[1]
        begin
          # try casting to an int, if it fails, no big deal
          value = value.to_i
        rescue TypeError
        end
        login_defs[param] = value
      end
    end
    login_defs
  end
end
