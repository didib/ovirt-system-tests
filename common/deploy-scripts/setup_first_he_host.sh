#!/bin/bash -x
HOSTEDENGINE="$1"
shift
HE_MAC_ADDRESS="$1"
shift

DOMAIN=$(dnsdomainname)
MYHOSTNAME="$(hostname | sed s/_/-/g)"
STORAGEHOSTNAME="${HOSTEDENGINE/engine/storage}"
VMPASS=123456
ENGINEPASS=123
HE_SETUP_HOOKS_DIR="/usr/share/ansible/collections/ansible_collections/ovirt/ovirt/roles/hosted_engine_setup/hooks"

# This is needed in case we're using prebuilt ost-images.
# In this scenario ssh keys are baked in to the qcows (so lago
# doesn't inject its own ssh keys), but HE VM is built from scratch.
copy_ssh_key() {
    cat << EOF > ${HE_SETUP_HOOKS_DIR}/enginevm_before_engine_setup/copy_ssh_key.yml
---
- name: Copy ssh key for root to HE VM
  authorized_key:
    user: root
    key: "{{ lookup('file', '/root/.ssh/authorized_keys') }}"
EOF

}

setup_ipv4() {
    MYADDR=$(\
        /sbin/ip -4 -o addr show dev eth0 \
        | awk '{split($4,a,"."); print a[1] "." a[2] "." a[3] "." a[4]}'\
        | awk -F/ '{print $1}' \
    )

    echo "${MYADDR} ${MYHOSTNAME}.${DOMAIN} ${MYHOSTNAME}" >> /etc/hosts

    HEGW=$(\
        /sbin/ip -4 -o addr show dev eth0 \
        | awk '{split($4,a,"."); print a[1] "." a[2] "." a[3] ".1"}'\
        | awk -F/ '{print $1}' \
    )
    HEADDR=$(\
        /sbin/ip -4 -o addr show dev eth0 \
        | awk '{split($4,a,"."); print a[1] "." a[2] "." a[3] ".99"}'\
        | awk -F/ '{print $1}' \
    )
    echo "${HEADDR} ${HOSTEDENGINE}.${DOMAIN} ${HOSTEDENGINE}" >> /etc/hosts

    INTERFACE=eth0
    PREFIX=24
}

setup_ipv6() {
    IPV6NET="fd8f:1391:3a82:"
    SUBNET=${IPV6_SUBNET}
    HE_SUFFIX=250
    INTERFACE=eth1
    PREFIX=64

    HOSTNAME_PREFIX=$(hostname | awk '{gsub(/[^-]*.[^-]*$/,""); print}')
    HEGW=${IPV6NET}${SUBNET}::1
    HEADDR=${IPV6NET}${SUBNET}::${HE_SUFFIX}

    cat << EOF > ${HE_SETUP_HOOKS_DIR}/enginevm_after_engine_setup/ipv6_dns_setup.yml
---
- name: Add /etc/hosts IPv6 entry for host-1
  lineinfile:
    dest: /etc/hosts
    line: "${IPV6NET}${SUBNET}::101 ${HOSTNAME_PREFIX}host-1"
EOF

    cat << EOF > ${HE_SETUP_HOOKS_DIR}/enginevm_after_engine_setup/disable_ssh_dns_lookup.yml
---
- name: Disable SSH reverse DNS lookup
  lineinfile:
    path: /etc/ssh/sshd_config
    regex: "^UseDNS"
    line: "UseDNS no"
- name: Restart sshd to make it effective
  systemd:
    state: restarted
    name: sshd
EOF

}

copy_ssh_key

if [[ $(hostname) == *"ipv6"* ]]; then
    setup_ipv6
else
    setup_ipv4
fi

sed \
    -e "s,@GW@,${HEGW},g" \
    -e "s,@ADDR@,${HEADDR},g" \
    -e "s,@VMPASS@,${VMPASS},g" \
    -e "s,@ENGINEPASS@,${ENGINEPASS},g" \
    -e "s,@DOMAIN@,${DOMAIN},g" \
    -e "s,@MYHOSTNAME@,${MYHOSTNAME}.${DOMAIN},g" \
    -e "s,@HOSTEDENGINE@,${HOSTEDENGINE},g" \
    -e "s,@STORAGEHOSTNAME@,${STORAGEHOSTNAME},g" \
    -e "s,@INTERFACE@,${INTERFACE},g" \
    -e "s,@PREFIX@,${PREFIX},g" \
    -e "s,@HE_MAC_ADDRESS@,${HE_MAC_ADDRESS},g" \
    < /root/hosted-engine-deploy-answers-file.conf.in \
    > /root/hosted-engine-deploy-answers-file.conf

appliance_ova_pattern=/usr/share/ovirt-engine-appliance/*.ova
# No quotes around $appliance_ova_pattern, we want it expanded if possible
if [ $(ls -1 $appliance_ova_pattern 2>/dev/null | wc -l) -eq 1 ]; then
    # If there is exactly one ova image, use it. This also makes the deploy
    # code not try to install/upgrade an appliance rpm.
    ova=$(ls -1 $appliance_ova_pattern)
    echo "OVEHOSTED_VM/ovfArchive=str:${ova}" >> /root/hosted-engine-deploy-answers-file.conf
fi

fstrim -va
rm -rf /var/cache/yum/*
hosted-engine --deploy --config-append=/root/hosted-engine-deploy-answers-file.conf
RET_CODE=$?
if [ ${RET_CODE} -ne 0 ]; then
    echo "hosted-engine deploy on ${MYHOSTNAME} failed with status ${RET_CODE}."
    exit ${RET_CODE}
fi
rm -rf /var/cache/yum/*
fstrim -va
