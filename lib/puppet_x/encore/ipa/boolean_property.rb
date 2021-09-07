require 'puppet_x/encore/ipa'

module PuppetX::Encore::Ipa
  # By default the Puppet Boolean property returns true/false values which is good for
  # enabling things, but not good for disabling. The reason is that inside the Puppet
  # code there is a lot of "if should" statements. This causes issues because if we
  # return a "real" boolean, it won't get evaluated. Instead we map our boolean into
  # a symbol :true or :false and compare against the symbol.
  #
  # Note: when using this property type, a symbol :true or :false will be returned
  #       NOT a boolean value
  class BooleanProperty < Puppet::Property
    # All values that are considered 'true' by Puppet internals
    def true_values
      [true, 'true', :true, :yes, 'yes']
    end

    # All values that are considered 'false' by Puppet internals
    def false_values
      [false, 'false', :false, :no, 'no', :undef, nil, :absent]
    end

    def munge(v)
      if true_values.include?(v)
        :true
      elsif false_values.include?(v)
        :false
      else
        raise ArgumentError, "Value '#{v}':#{v.class} cannot be determined as a boolean value"
      end
    end

    def insync?(is)
      munge(is) == munge(should)
    end

    def self.defaultvalues
      newvalue(:true)
      newvalue(:false)
      aliasvalue(true, :true)
      aliasvalue(false, :false)

      aliasvalue('true', :true)
      aliasvalue('false', :false)

      aliasvalue(:yes, :true)
      aliasvalue(:no, :false)

      aliasvalue('yes', :true)
      aliasvalue('no', :false)

      validate do |value|
        munge(value)
      end
    end
  end
end
