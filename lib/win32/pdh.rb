require 'win32/pdh/constants'

module Win32
  module PdhFFI
    extend FFI::Library
    ffi_lib :Pdh

    typedef :pointer, :pdh_hquery
    typedef :pointer, :pdh_hcounter
    typedef :uint, :pdh_status

    attach_function :PdhOpenQueryA, [:string, :pointer, :pointer], :pdh_status
  end
end
