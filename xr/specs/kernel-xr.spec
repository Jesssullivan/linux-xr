# kernel-xr.spec — XR-optimized kernel RPM for Rocky Linux 10
#
# Build: rpmbuild -bb \
#   --define "kversion 6.19.5" \
#   --define "xr_release 1" \
#   --define "rt_version 6.19.3-rt1" \
#   kernel-xr.spec
#
# The build-rpm.sh script handles source/patch fetching and calls this.

%define kversion  %{?kversion}%{!?kversion:6.19.5}
%define xr_release %{?xr_release}%{!?xr_release:1}
%define krelease  %{xr_release}.xr.el10
%define rt_version %{?rt_version}%{!?rt_version:%{nil}}

Name:           kernel-xr
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
BuildRequires:  perl-interpreter
BuildRequires:  bc
BuildRequires:  bison
BuildRequires:  flex
BuildRequires:  rsync
BuildRequires:  rpm-build
BuildRequires:  dwarves

Provides:       kernel = %{kversion}-%{krelease}
Conflicts:      kernel-xr < %{kversion}-%{krelease}

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
%patch -P1 -p1 --fuzz=3

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

# RT-specific config
%if "%{rt_version}" != ""
scripts/config --enable CONFIG_PREEMPT_RT
scripts/config --disable CONFIG_PREEMPT_VOLUNTARY
scripts/config --disable CONFIG_PREEMPT_NONE
%endif

make olddefconfig

%build
make -j$(nproc) bzImage modules

%install
mkdir -p %{buildroot}/boot
mkdir -p %{buildroot}/lib/modules

make INSTALL_MOD_PATH=%{buildroot} modules_install
make INSTALL_PATH=%{buildroot}/boot install

# Install vmlinux for devel
mkdir -p %{buildroot}/usr/src/kernels/%{kversion}-%{krelease}
cp -a .config Module.symvers System.map Makefile \
    %{buildroot}/usr/src/kernels/%{kversion}-%{krelease}/
cp -a include scripts arch/x86/include \
    %{buildroot}/usr/src/kernels/%{kversion}-%{krelease}/

# Headers
make INSTALL_HDR_PATH=%{buildroot}/usr headers_install

# Remove build/source symlinks (point to builddir)
rm -f %{buildroot}/lib/modules/%{kversion}-%{krelease}/build
rm -f %{buildroot}/lib/modules/%{kversion}-%{krelease}/source
ln -sf /usr/src/kernels/%{kversion}-%{krelease} \
    %{buildroot}/lib/modules/%{kversion}-%{krelease}/build

%post
depmod -a %{kversion}-%{krelease}
grubby --set-default /boot/vmlinuz-%{kversion}-%{krelease} || true

%postun
if [ $1 -eq 0 ]; then
    depmod -a
fi

%files
/boot/vmlinuz-%{kversion}-%{krelease}
/boot/System.map-%{kversion}-%{krelease}
/boot/config-%{kversion}-%{krelease}
/lib/modules/%{kversion}-%{krelease}/

%files devel
/usr/src/kernels/%{kversion}-%{krelease}/

%files headers
/usr/include/*
