"""
Increases the Windows system timer resolution to 1 ms.

Without this, `sleep` (used by [`Scheduler`](@ref)'s `fps` limiting) is
rounded up to the OS's default timer tick of ~15.6 ms, making short waits
far less precise than requested. No-op on non-Windows systems.

Mirrors `initTimer` from the sibling Go implementation's
`github.com/mlange-42/ark-tools/app` package.
See https://github.com/golang/go/issues/44343.
"""
function _init_timer()
    @static if Sys.iswindows()
        ccall((:timeBeginPeriod, "winmm"), stdcall, Cuint, (Cuint,), UInt32(1))
    end
    return nothing
end
