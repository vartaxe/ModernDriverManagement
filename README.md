# Modern Driver Management

For implementation instructions, please go to https://www.msendpointmgr.com/modern-driver-management

## Scope

Modern Driver Management selects, downloads, and applies approved ConfigMgr
driver packages. OEM catalog acquisition, normalization, validation, and
package creation belong in the Driver Automation Tool or another controlled
content-management process.

Use separate approved profiles for OEM model packages, component supplements,
WinPE drivers, and offline/recovery content. Third-party sources must be
imported and validated by an administrator; this script does not query or
trust them automatically.

Virtual-machine processing is opt-in with `-AllowVirtualMachine`. When enabled,
only packages explicitly labelled for virtual hardware are eligible. Without
it, the existing virtual-machine refusal remains in place. `-DebugMode` is
detection and matching diagnostics only; it does not download or install
content.