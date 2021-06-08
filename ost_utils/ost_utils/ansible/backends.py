#
# Copyright 2021 Red Hat, Inc.
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

import os
import tempfile


class Backends(object):
    """A class to handle a collection of backends"""

    def __init__(self):
        self.backends = {}

    def add(self, name, backend):
        """Add a backend to the collection
        input:
            name: a string
            backend: an instance of (a subclass of) BaseBackend
        """
        if name not in self.backends:
            backends[name] = backend

    def deploy_scripts(self):
        res = {}
        for k,v in self.backends:
            res.update(v.deploy_scripts())
        return res

    def hostnames(self):
        res = set()
        for k,v in self.backends:
            res |= v.hostnames()
        return res

    def hosts_hostnames(self):
        # The output should always be sorted, so we can refer by indices
        return sorted(hn for hn in self.hostnames() if "host" in hn)

    def storage_hostname(self):
        # Storage VM does not always exist - some suites do not define it
        return next((hn for hn in self.hostnames() if "storage" in hn), None)

    def ansible_inventory(self):
        # All backends hopefully use the same ansible inventory directory.
        # Use the first one.
        # TODO: Remove this once all users use instead the ansible_inventory
        # fixture directly.
        res = None
        if self.backends:
            res = list(self.backends.values())[0]
        return res

    def iface_mapping(self):
        res = {}
        for k,v in self.backends:
            res.update(v.iface_mapping())
        return res

    def ifaces_for(self, hostname, network_name):
        return self.iface_mapping()[hostname][network_name]

