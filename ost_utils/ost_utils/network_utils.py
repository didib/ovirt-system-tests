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

import socket


def find_free_port(start, stop, host="127.0.0.1", timeout=0.1):
    for port in range(start, stop):
        try:
            s = socket.create_connection((host, port), timeout)
        except ConnectionRefusedError:
            return port
        else:
            s.close()
    raise RuntimeError("No free port could be found")


def get_ips(backend, ansible_facts, network_name):
    hostname = ansible_facts.get("ansible_hostname")
    ifaces = backend.ifaces_for(hostname, network_name)
    ips = [
        ansible_facts.get("ansible_{}.ipv4.address".format(iface))
        for iface in ifaces
    ]
    return ips
