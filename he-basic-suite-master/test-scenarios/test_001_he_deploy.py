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

import functools
import os


def run_dig_loop(ansible_host0, run_loop_script, log):
    ansible_host0.shell(f'{run_loop_script} {log}')


def test_run_dig_loop(suite_dir, ansible_host0, run_dig_loop_vt):
    script_name = 'run_dig_loop.sh'
    run_dig_loop_src = os.path.join(suite_dir, script_name)
    ansible_host0.copy(src=run_dig_loop_src, dest='/root/', mode='preserve')
    run_dig_loop_vt.targets = [
        functools.partial(
            run_dig_loop,
            ansible_host0,
            os.path.join('/root', script_name),
            '/var/log/run_dig_loop.log',
        ),
    ]
    run_dig_loop_vt.start_all()


def test_he_deploy(
    suite_dir,
    ansible_host0,
    ansible_storage,
    he_host_name,
    he_mac_address,
    he_ipv4_address,
):
    answer_file_src = os.path.join(suite_dir, 'answers.conf.in')
    ansible_host0.copy(
        src=answer_file_src,
        dest='/root/hosted-engine-deploy-answers-file.conf.in'
    )

    setup_file_src = os.path.join(suite_dir, 'setup_first_he_host.sh')
    ansible_host0.copy(src=setup_file_src, dest='/root/', mode='preserve')

    ansible_host0.shell(
        '/root/setup_first_he_host.sh '
        f'{he_host_name} '
        f'{he_mac_address} '
        f'{he_ipv4_address}'
    )

    ansible_storage.shell('fstrim -va')
