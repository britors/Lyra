#
# spec file for package lyra-fish-productivity
#
# Copyright (c) 2026 Rodrigo Brito
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon.
#
# This file is licensed under the GPL-3.0-only license, see the LICENSE file.
#

Name:           lyra-fish-productivity
Version:        1.0.0
Release:        0
Summary:        Fisher and the curated fish plugin set of Lyra OS
License:        GPL-3.0-only
URL:            https://github.com/britors/Lyra
Source0:        %{name}-%{version}.tar.xz
BuildArch:      noarch

# %%check parses every shipped snippet with fish --no-execute.
BuildRequires:  fish

# fish is the default shell of the Lyra OS desktop account; this package is
# the productivity layer on top of it. fzf backs PatrickF1/fzf.fish, and
# curl fetches Fisher, which upstream does not ship as an RPM.
Requires:       fish >= 3.4
Requires:       fzf
Requires:       curl
Requires:       git

# nvm-fish ships the same function names in the vendor directories. Both can
# coexist: ~/.config/fish precedes them in $fish_function_path, so the Fisher
# copy wins for accounts that ran the setup and the packaged one remains the
# fallback for every other account. Recommends, not Requires: the pack is
# useful without it.
Recommends:     nvm-fish

%description
Fisher plus the fish plugin set validated for Lyra OS: fzf.fish, z,
autopair.fish, done, hydro, bass, plugin-git and nvm.fish.

The plugin set is installed per account under ~/.config/fish. On a Lyra OS
image the setup runs at build time and is seeded through /etc/skel, so a new
installation has everything on its first terminal, with no network access.
On any other account the fish_setup_lyra_plugins function installs the same
set on demand, and lyra_fish_status reports what is installed and active.

%prep
%autosetup

%build
# The functions report the packaged version so that an update which changes
# the canonical plugin list triggers exactly one re-run per account.
sed -i 's/@VERSION@/%{version}/g' functions/__lyra_fish_version.fish

%install
install -d %{buildroot}%{_datadir}/fish/vendor_functions.d
install -d %{buildroot}%{_datadir}/fish/vendor_conf.d
install -d %{buildroot}%{_datadir}/%{name}

install -m 0644 functions/*.fish %{buildroot}%{_datadir}/fish/vendor_functions.d/
install -m 0644 conf.d/lyra-fish-bootstrap.fish %{buildroot}%{_datadir}/fish/vendor_conf.d/
install -m 0644 fish_plugins %{buildroot}%{_datadir}/%{name}/fish_plugins

%check
# Every shipped snippet must parse; a syntax error here would break the
# login shell of every account on the system.
fish --no-execute functions/*.fish conf.d/*.fish

%files
%license LICENSE
%doc docs/README.md
%dir %{_datadir}/%{name}
%{_datadir}/%{name}/fish_plugins
%{_datadir}/fish/vendor_functions.d/*.fish
%{_datadir}/fish/vendor_conf.d/lyra-fish-bootstrap.fish

%changelog
