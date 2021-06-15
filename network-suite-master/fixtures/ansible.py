# Copyright 2020-2021 Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
#
# Refer to the README and COPYING files for full details of the license
#

import ipaddress
import pytest

from ost_utils import ansible
from ost_utils.ansible import private_dir


@pytest.fixture(scope="session")
def engine_facts(ansible_engine_facts):
    return MachineFacts(
        ansible_engine_facts.get('ansible_default_ipv4').get('address'),
        ansible_engine_facts.get('ansible_hostname')
    )


@pytest.fixture(scope="session")
def host0_facts(ansible_host0_facts):
    return MachineFacts(
        ansible_host0_facts.get('ansible_default_ipv4').get('address'),
        ansible_host0_facts.get('ansible_hostname')
    )


@pytest.fixture(scope="session")
def host1_facts(ansible_host1_facts):
    return MachineFacts(
        ansible_host1_facts.get('ansible_default_ipv4').get('address'),
        ansible_host1_facts.get('ansible_hostname')
    )


@pytest.fixture(scope="session", autouse=True)
def ansible_clean_private_dirs():
    yield
    private_dir.PrivateDir.cleanup()


@pytest.fixture(scope="session", autouse=True)
def ansible_collect_logs(artifacts_dir, ansible_clean_private_dirs):
    yield
    ansible.LogsCollector.save(artifacts_dir)


class MachineFacts(object):
    """
    ost_utils.ansible.ansible_facts retrieves information from the remote
    machine whenever its get attribute is called. When an ansible service is
    present and fetches the facts MachineFacts caches the ansible response as a
    simple collection of machine access info.
    When an ansible service is not present in an independent environment
    MachineFacts can be easily instantiated with access info for the engine and
    hosts in the environment, enabling fast and easy setup for testing and
    debugging.

    MachineFacts therefore serves as an adapter that encapsulates dependency
    upon the ost_utils-ansible stack from the network suite for multiple use
    cases.
    """

    def __init__(self, default_ip, hostname, ssh_password='123456'):
        self._default_ip = default_ip
        self._url_ip = self._make_url_ip()
        self._hostname = hostname
        self._ssh_password = ssh_password

    @property
    def default_ip(self):
        return self._default_ip

    @property
    def url_ip(self):
        return self._url_ip

    @property
    def hostname(self):
        return self._hostname

    @property
    def ssh_password(self):
        return self._ssh_password

    def _make_url_ip(self):
        ip = ipaddress.ip_address(self._default_ip)
        return self._default_ip if ip.version == 4 else f'[{self._default_ip}]'
