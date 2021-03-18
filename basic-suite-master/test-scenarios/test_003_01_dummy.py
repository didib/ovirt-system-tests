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

import functools
import logging
import os

from ost_utils import utils
from ost_utils.ansible import AnsibleExecutionError
from ost_utils.pytest.fixtures.ansible import ansible_engine
from ost_utils.pytest.fixtures.ansible import ansible_hosts


LOGGER = logging.getLogger(__name__)


def do_something_1(ansible_engine):
    LOGGER.info(f'do_something_1: Start')
    mam = ansible_engine.shell
    LOGGER.info(f'do_something_1: mam: {mam}')
    res = mam('echo $(date) $(hostname) something 1')
    LOGGER.info(f'do_something_1: res: {res["stdout"]}')


def do_something_2(ansible_engine):
    LOGGER.info(f'do_something_2: Start')
    mam = ansible_engine.shell
    LOGGER.info(f'do_something_2: mam: {mam}')
    res = mam('echo $(date) $(hostname) something 2')
    LOGGER.info(f'do_something_2: res: {res["stdout"]}')

def test_dummy(ansible_engine):
    for i in range(1000):
        LOGGER.info(f'test_dummy: Starting iteration {i}')
        vt = utils.VectorThread(
            [
                functools.partial(do_something_1, ansible_engine),
                functools.partial(do_something_2, ansible_engine),
            ],
        )
        vt.start_all()
        vt.join_all()
