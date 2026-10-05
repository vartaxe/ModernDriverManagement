# Modern Driver Management

For implementation instructions, please go to https://www.msendpointmgr.com/modern-driver-management

## Virtual machines

`Invoke-CMApplyDriverPackage.ps1` blocks detected virtual machines by default. Use
`-AllowVirtualMachine` to opt in to virtual-machine driver package deployment.
VMware platform detection uses the case-insensitive `VMware*` wildcard, recognizing
`VMware Virtual Platform`, `VMware7,1`, `VMware 7,1`, and future VMware-prefixed
model strings without requiring a new entry for each model.
These identifiers are not treated as VMware virtual hardware version numbers.
Hyper-V detection requires the exact model `Virtual Machine` together with a
manufacturer containing `Microsoft`. This covers both Generation 1 and Generation 2;
these fields do not distinguish their firmware or generation. The generic model
alone is not treated as Hyper-V.

VirtualBox is recognized by the exact model `VirtualBox`, including guests reporting
`innotek GmbH` or `Oracle Corporation` as manufacturer. QEMU/KVM detection recognizes
models containing `Standard PC` or `KVM`, or a manufacturer containing `QEMU`.
A Red Hat manufacturer is accepted when the model also contains `Virtual Machine`,
rather than treating every Red Hat system as a VM. Xen/Citrix detection recognizes
`HVM domU` and models or manufacturers containing `Xen` or `Citrix` before the
QEMU/KVM and physical OEM checks. The `Hypervisor-XenCitrix` label identifies the
family, not a specific host product. Virtual package labels include `Citrix`,
`Xen`, `XenServer`, and `XenEnterprise`.
The platform, manufacturer, and model are logged.

QEMU/KVM identification does not distinguish Proxmox from other QEMU/KVM hosts or
infer firmware/chipset from a model string. The script deploys matching INF driver
packages; it does not automatically run VMware Tools, VirtualBox Guest Additions,
or other guest-tools installers based solely on platform detection.

Physical OEM classification runs only after hypervisor detection. Logged labels
cover Dell, Alienware, HP/Hewlett-Packard, Lenovo, Fujitsu, Panasonic, ASUS/ASUSTeK,
Acer, Intel (including NUC models), and Microsoft Surface. Surface requires both a
Microsoft manufacturer and a model containing `Surface`. Unlisted brands are logged
as `Physical-Unknown` and still use the existing manufacturer/model package matching.
OEM labels are informational: they do not replace manufacturer normalization, SKU
detection, or package validation, and do not trigger vendor tools or MSI installers.

Existing manufacturer, exact model, Windows version, and architecture matching
rules still apply. Packages must also be explicitly labelled for virtual hardware
in their name, description, or manufacturer. Detection of another numbered VMware
model does not make packages for `VMware7,1` interchangeable with it. DebugMode
permits detection on virtual machines without downloading or installing drivers.

XML deployments accept `OSUpgrade`; the existing `OSUpdate` value is an alias that
also stages content for Windows Setup. Missing XML package files stop execution.
SystemSKU lists support comma, semicolon, and whitespace separators and match
complete tokens, not substrings or regular expressions. Arm64 is recognized in
fallback packages as well as regular packages. DriverUpdate logs PnPUtil output
to `Install-Drivers.txt`, accepts success/restart-required exit codes (0/3010),
and stops on other failures instead of reporting success.