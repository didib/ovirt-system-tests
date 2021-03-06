#
# Copyright 2020 Red Hat, Inc.
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

import datetime

import logging
LOGGER = logging.getLogger('')


RUNNING_TIMES = {}


def pytest_runtest_logstart(nodeid, location):
    now = datetime.datetime.now()
    RUNNING_TIMES[location] = now
    print(now.strftime('started at %Y-%m-%d %H:%M:%S'), end=' ')
    LOGGER.debug(f'Running test: {nodeid}')


def pytest_runtest_logfinish(nodeid, location):
    now = datetime.datetime.now()
    then = RUNNING_TIMES[location]
    delta = int((now - then).total_seconds())
    print(" ({}s)".format(delta), end='')
    LOGGER.debug(f'Finished test: {nodeid} ({delta}s)')
