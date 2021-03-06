# -*- coding: utf-8 -*-
#
# Copyright 2014, 2017, 2019 Red Hat, Inc.
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

import pytest

from os import environ, path

from ost_utils import assertions
from ost_utils import general_utils
from ost_utils.pytest import order_by
from ost_utils.pytest.fixtures.engine import *
from ost_utils import shell
from ost_utils import utils

import logging
LOGGER = logging.getLogger(__name__)

def test_run_ocp_installer():
    # assert engine_full_username == "admin@inetdsfdf"
    # call test-ocp-installer.sh here
    pass
