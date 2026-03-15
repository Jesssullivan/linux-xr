# kernel-xr.spec — XR-optimized kernel RPM for Rocky Linux 10
#
# Build: rpmbuild -bb \
#   --define "kversion 6.19.5" \
#   --define "xr_release 1" \
#   --define "rt_version 6.19.3-rt1" \
#   --define "variant -rt" \
#   kernel-xr.spec
#
# The build-rpm.sh script handles source/patch fetching and calls this.

%{!?kversion: %global kversion 6.19.5}
%{!?xr_release: %global xr_release 1}
%global krelease  %{xr_release}.xr.el10
%{!?rt_version: %global rt_version %{nil}}
%{!?variant: %global variant %{nil}}

Name:           kernel-xr%{variant}
Version:        %{kversion}
Release:        %{krelease}
Summary:        XR-optimized kernel with DSC fixes for Bigscreen Beyond 2e
License:        GPL-2.0-only
URL:            https://github.com/Jesssullivan/linux-xr

Source0:        linux-%{kversion}.tar.xz
Source1:        base.config

# XR patches (fetched by build-rpm.sh into SOURCES/)
Patch0:         0007-vesa-dsc-bpp.patch
Patch1:         bigscreen-beyond-edid.patch

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  elfutils-libelf-devel
BuildRequires:  openssl-devel
BuildRequires:  openssl
BuildRequires:  perl-interpreter
BuildRequires:  bc
BuildRequires:  bison
BuildRequires:  flex
BuildRequires:  rsync
BuildRequires:  rpm-build
BuildRequires:  dwarves
BuildRequires:  kmod

Requires:       dracut
Requires:       grubby

Provides:       kernel-xr%{variant} = %{kversion}-%{krelease}
Provides:       kernel = %{kversion}-%{krelease}

%description
Linux kernel %{kversion} with XR/VR patches for Bigscreen Beyond 2e headsets
on AMD GPUs (RDNA2+). Includes:
- VESA DisplayID DSC BPP parser (CachyOS combined patch)
- EDID non-desktop quirk for Beyond (BIG/0x1234)
- DSC QP table corrections for 8bpc 4:4:4 at 8 BPP
- RC offset fix for ofs[11] in get_ofs_set() CM_444/CM_RGB
%if "%{rt_version}" != ""
- PREEMPT_RT real-time scheduling (%{rt_version})
%endif

%package devel
Summary:        Development files for kernel-xr %{kversion}
Provides:       kernel-devel = %{kversion}-%{krelease}

%description devel
Kernel headers and build support files for compiling out-of-tree modules
against kernel-xr %{kversion}-%{krelease}.

%package headers
Summary:        Header files for kernel-xr %{kversion}
Provides:       kernel-headers = %{kversion}-%{krelease}

%description headers
Userspace API header files for kernel-xr %{kversion}-%{krelease}.

%prep
%setup -q -n linux-%{kversion}

# Apply RT patch first (if building RT kernel)
%if "%{rt_version}" != ""
patch -p1 < %{_sourcedir}/patch-%{rt_version}.patch
%endif

# CachyOS combined: VESA DSC BPP parser + QP tables + RC offsets + amdgpu_dm
%patch -P0 -p1

# EDID non-desktop quirk for Beyond (fuzz needed: context shifted by DSC patch)
patch -p1 --fuzz=3 < %{_sourcedir}/bigscreen-beyond-edid.patch

# Apply base config from honey server
cp %{SOURCE1} .config

# XR-specific config overrides
scripts/config --set-val CONFIG_HZ 1000
scripts/config --enable CONFIG_HZ_1000
scripts/config --disable CONFIG_HZ_250
scripts/config --enable CONFIG_DRM_AMD_DC_DSC
scripts/config --enable CONFIG_DRM_AMD_DC_FP
scripts/config --enable CONFIG_USB_HIDDEV
scripts/config --enable CONFIG_USB_VIDEO_CLASS
scripts/config --set-str CONFIG_LOCALVERSION "-%{krelease}"

# SMI mitigation config (from Dell T7810 BIOS RE analysis)
# These ensure the kernel ships tools for characterizing and mitigating
# SMI-induced latency on C610/Wellsburg PCH systems.
scripts/config --enable CONFIG_HWLAT_TRACER
scripts/config --enable CONFIG_TRACER_SNAPSHOT
scripts/config --enable CONFIG_X86_MSR
scripts/config --module CONFIG_DELL_RBU
scripts/config --disable CONFIG_ITCO_WDT

# BCI workload support (CPU isolation, high-res timers)
scripts/config --enable CONFIG_CPU_ISOLATION
scripts/config --enable CONFIG_NO_HZ_FULL
scripts/config --enable CONFIG_HIGH_RES_TIMERS
scripts/config --enable CONFIG_RCU_NOCB_CPU
scripts/config --enable CONFIG_IRQ_FORCED_THREADING
scripts/config --enable CONFIG_UIO
scripts/config --enable CONFIG_UIO_PCI_GENERIC

# RT-specific config
%if "%{rt_version}" != ""
scripts/config --enable CONFIG_PREEMPT_RT
scripts/config --disable CONFIG_PREEMPT_VOLUNTARY
scripts/config --disable CONFIG_PREEMPT_NONE
%endif

# Reduce debug info to cut link-time memory (~8GB -> ~2GB for vmlinux)
# CRITICAL: keep CONFIG_DEBUG_INFO_BTF=y — systemd 256 uses BPF for cgroup
# management and will hang at switch-root without BTF support.
# Use CONFIG_DEBUG_INFO_REDUCED instead of CONFIG_DEBUG_INFO_NONE.
scripts/config --enable CONFIG_DEBUG_INFO
scripts/config --enable CONFIG_DEBUG_INFO_REDUCED
scripts/config --disable CONFIG_DEBUG_INFO_DWARF5
scripts/config --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
scripts/config --enable CONFIG_DEBUG_INFO_BTF
scripts/config --enable CONFIG_DEBUG_INFO_BTF_MODULES

make olddefconfig

# Capture the actual kernel release string (includes -rt1 if RT patched)
KREL=$(make -s kernelrelease)
echo "Kernel release: ${KREL}"
echo "${KREL}" > .kernel-release

%build
KREL=$(cat .kernel-release)
# Cap parallelism: containers report host nproc, not cgroup CPU limit.
# Kernel compilation uses ~1GB per gcc job; limit to avoid OOM on CI runners.
JOBS=$(nproc 2>/dev/null || echo 2)
[ "$JOBS" -gt 4 ] && JOBS=4
make %{?_cc:CC="%{_cc}"} -j${JOBS} V=0 bzImage modules

%install
KREL=$(cat .kernel-release)
mkdir -p %{buildroot}/boot
mkdir -p %{buildroot}/lib/modules

make INSTALL_MOD_PATH=%{buildroot} modules_install
make INSTALL_PATH=%{buildroot}/boot install

# Install vmlinux for devel
mkdir -p %{buildroot}/usr/src/kernels/${KREL}
cp -a .config Module.symvers System.map Makefile \
    %{buildroot}/usr/src/kernels/${KREL}/
cp -a include scripts arch/x86/include \
    %{buildroot}/usr/src/kernels/${KREL}/

# Headers
make INSTALL_HDR_PATH=%{buildroot}/usr headers_install

# Remove build/source symlinks (point to builddir)
rm -f %{buildroot}/lib/modules/${KREL}/build
rm -f %{buildroot}/lib/modules/${KREL}/source
ln -sf /usr/src/kernels/${KREL} \
    %{buildroot}/lib/modules/${KREL}/build

%post
KREL=%{kversion}-%{krelease}
# Find the actual installed kernel version (may include -rt suffix)
ACTUAL_KREL=$(ls /lib/modules/ | grep "%{kversion}.*%{krelease}" | head -1)
depmod -a ${ACTUAL_KREL:-${KREL}}

# Generate initramfs (CRITICAL: without this, storage drivers won't load)
if [ -x /usr/bin/dracut ]; then
    /usr/bin/dracut --force /boot/initramfs-${ACTUAL_KREL:-${KREL}}.img ${ACTUAL_KREL:-${KREL}}
fi

# Set as default boot kernel
grubby --set-default /boot/vmlinuz-${ACTUAL_KREL:-${KREL}} || true

# Apply hardware-invariant SMI mitigation boot params (from Dell T7810 BIOS RE)
# Topology-dependent params (isolcpus, nohz_full) are left to the tuned profile.
grubby --update-kernel=/boot/vmlinuz-${ACTUAL_KREL:-${KREL}} \
  --args="tsc=nowatchdog clocksource=tsc nosoftlockup nmi_watchdog=0" || true

echo ""
echo "kernel-xr installed: ${ACTUAL_KREL:-${KREL}}"
echo ""
echo "For RT/BCI workloads, install the xr-bci tuned profile:"
echo "  sudo tuned-adm profile xr-bci"
echo "  sudo reboot"
echo "Validate: sudo smi-validate --full"

%postun
if [ $1 -eq 0 ]; then
    depmod -a
fi

%files
/boot/*%{kversion}*%{krelease}*
/lib/modules/*%{kversion}*%{krelease}*/

%files devel
/usr/src/kernels/*%{kversion}*%{krelease}*/

%files headers
/usr/include/*
