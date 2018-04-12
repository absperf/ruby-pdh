#require 'win32/pdh/constants'

require 'ffi'

module Win32
  module PdhFFI
    extend FFI::Library
    ffi_lib :Pdh

    typedef :pointer, :pdh_hquery
    typedef :pointer, :pdh_hcounter
    typedef :uint, :pdh_status

    attach_function :PdhOpenQueryW, [:buffer_in, :buffer_in, :buffer_out], :pdh_status

    ##
    # Simple query opening function.  Uses the OpenQuery function and gets a
    # query, passes it into the block, and then closes it afterward.
    def self.query
    end
  end
end
