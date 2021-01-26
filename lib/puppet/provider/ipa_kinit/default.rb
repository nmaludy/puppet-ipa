require 'puppet/provider/ipa'

Puppet::Type.type(:ipa_kinit).provide(:default, parent: Puppet::Provider::Ipa) do
  defaultfor kernel: 'Linux'

  commands kinit: 'kinit'
  commands klist: 'klist'
  commands kdestroy: 'kdestroy'

  # always need to define this in our implementation classes
  mk_resource_methods

  ##########################
  # private methods that we need to implement because we inherit from Puppet::Provider::Synapse

  # this method should retrieve an instance and return it as a hash
  # note: we explicitly do NOT cache within this method because we want to be
  #       able to call it both in initialize() and in flush() and return the current
  #       state of the resource from the API each time
  def read_instance
    instance = nil
    begin
      # -l : outputs in a tabular format that is easier to grep/find our user name
      output = klist('-l')
      Puppet.debug("klist got output: #{output}")
      output.lines.each do |line|
        # compare downcase in case (for some reason) they change the text in a new version
        next if line.downcase.start_with?('principal name')
        next if line.start_with?('--------------')
        # filter out expired tickets
        next if line.downcase.include?('(expired)')

        line_parts = line.split(' ')
        principal_name = line_parts[0]
        principal_parts = principal_name.split('@')
        principal_user = principal_parts[0]
        principal_realm = principal_parts[1]

        Puppet.debug("klist got principal_name: #{principal_name}")
        Puppet.debug("klist got principal_user: #{principal_user}")
        Puppet.debug("klist got principal_realm: #{principal_realm}")
        next if resource[:name] != principal_user

        Puppet.debug('klist principal_user matches our user!')
        if resource[:realm]
          Puppet.debug("klist has a realm #{resource[:realm]}")
          next if resource[:realm] != principal_realm

          Puppet.debug('klist principal_realm matches our realm!')
          instance = {
            ensure: :present,
            name: principal_user,
            realm: principal_realm,
            principal_name: principal_name,
          }
        else
          # no realm passed in, assume username/principal matching is good enough
          Puppet.debug('klist no realm was passed in and our principal user matches, good enough!')
          instance = {
            ensure: :present,
            name: principal_user,
            principal_name: principal_name,
          }
        end
        break
      end
    rescue Puppet::ExecutionFailure => e
      Puppet.debug("klist returned an error: #{e}")
    end
    instance = { ensure: :absent, name: resource[:name] } if instance.nil?
    Puppet.debug("klist instance = #{instance}")
    instance
  end

  # this method should check resource[:ensure]
  #  if it is :present this method should create/update the instance using the values
  #  in resource[:xxx] (these are the desired state values)
  #  else if it is :absent this method should delete the instance
  #
  #  if you want to have access to the values before they were changed you can use
  #  cached_instance[:xxx] to compare against (that's why it exists)
  def flush_instance
    case resource[:ensure]
    when :absent
      kdestroy(['-p', cached_instance[:principal_name]])
    when :present
      # use environment here to pass in password so it doesn't leak
      kinit_name = resource[:name]
      kinit_name += "@#{resource[:realm]}" if resource[:realm]
      command_str = "echo $KINIT_PASSWORD | #{command(:kinit)} #{kinit_name}"
      Puppet::Util::Execution.execute(command_str,
                                      override_locale: false,
                                      failonfail: true,
                                      combine: true,
                                      custom_environment: {
                                        'KINIT_PASSWORD' => resource[:password],
                                      })
    end
  end
end
