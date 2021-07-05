#
# Copyright 2014 Red Hat, Inc.
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
from __future__ import absolute_import

import os
import tempfile

import ovirtsdk4.types as types
import pytest

from ost_utils import engine_utils

# AAA
AAA_LDAP_USER = 'user1'
AAA_LDAP_GROUP = 'mygroup'
AAA_LDAP_AUTHZ_PROVIDER = 'lago.local-authz'


@pytest.fixture(scope="session")
def ansible_machine_389ds(ansible_engine):
    return ansible_engine


@pytest.fixture(scope="session")
def machine_389ds_ip(engine_ip):
    return engine_ip


def test_add_ldap_provider(suite_dir, ansible_engine, ansible_machine_389ds,
                           machine_389ds_ip, engine_restart):
    answer_file_src = os.path.join(suite_dir, 'aaa-ldap-answer-file.conf')

    with open(answer_file_src, 'r') as f:
        content = f.read()
        content = content.replace('@389DS_IP@', machine_389ds_ip)

    with tempfile.NamedTemporaryFile(mode='w') as temp:
        temp.write(content)
        temp.flush()
        os.fsync(temp.fileno())
        ansible_engine.copy(src=temp.name, dest='/root/aaa-ldap-answer-file.conf')

    ansible_machine_389ds.systemd(name='dirsrv@lago', state='started')

    ansible_engine.shell(
        'ovirt-engine-extension-aaa-ldap-setup '
        '--config-append=/root/aaa-ldap-answer-file.conf '
        '--log=/var/log/ovirt-engine-extension-aaa-ldap-setup.log'
    )

    engine_restart()


def test_add_ldap_group(engine_api):
    engine = engine_api.system_service()
    groups_service = engine.groups_service()
    with engine_utils.wait_for_event(engine, 149): # USER_ADD(149)
        groups_service.add(
            types.Group(
                name=AAA_LDAP_GROUP,
                domain=types.Domain(
                    name=AAA_LDAP_AUTHZ_PROVIDER
                ),
            ),
        )


def test_add_ldap_user(engine_api):
    engine = engine_api.system_service()
    users_service = engine.users_service()
    with engine_utils.wait_for_event(engine, 149): # USER_ADD(149)
        users_service.add(
            types.User(
                user_name=AAA_LDAP_USER,
                domain=types.Domain(
                    name=AAA_LDAP_AUTHZ_PROVIDER
                ),
            ),
        )
