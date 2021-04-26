#!/bin/bash -xe
set -xe
MAIN_NFS_DEV="disk/by-id/scsi-0QEMU_QEMU_HARDDISK_2"
ISCSI_DEV="disk/by-id/scsi-0QEMU_QEMU_HARDDISK_3"
NUM_LUNS=5
DIST=$(uname -r |awk -F\. '{print $(NF-1)}')


setup_device() {
    local device=$1
    local mountpath=$2
    mkdir -p ${mountpath}
    mkfs.ext4 -E nodiscard -F /dev/${device}
    echo -e "/dev/${device}\t${mountpath}\text4\tdefaults\t0 0" >> /etc/fstab
    mount /dev/${device} ${mountpath}
}

setup_nfs() {
    local exportpath=$1
    mkdir -p ${exportpath}
    chmod a+rwx ${exportpath}
    echo "${exportpath} *(rw,async,anonuid=36,anongid=36,all_squash)" >> /etc/exports
}

activate_nfs() {
    exportfs -a
}


setup_main_nfs() {
    setup_device ${MAIN_NFS_DEV} /exports/nfs
    setup_nfs /exports/nfs/share1
}


setup_export() {
    setup_nfs /exports/nfs/exported
}


setup_iso() {
    setup_nfs /exports/nfs/iso
}


setup_second_nfs() {
    setup_nfs /exports/nfs/share2
}

set_selinux_on_nfs() {
    semanage fcontext -a -t nfs_t '/exports/nfs(/.*)?'
    restorecon -Rv /exports/nfs
}

install_deps() {
    systemctl disable --now kdump.service
    pkgs_to_install=(
    "nfs-utils"
    "rpcbind"
    "lvm2"
    "targetcli"
    "sg3_utils"
    "iscsi-initiator-utils"
    "policycoreutils-python-utils"
    )
    rpm -q "${pkgs_to_install[@]}" >/dev/null || yum install --nogpgcheck -y "${pkgs_to_install[@]}" || {
        ret=$?
        echo "install failed with status $ret"
        exit $ret
    }
}


setup_iscsi() {
    # this is ugly, assumes that dedicated storage VMs (lago-[suite]-storage) use their primary network as storage network, and VMs with co-located engine have a dedicated storage network on eth1 (like basic-suite-master). And in both cases these are assumed to be ipv4, ipv6-only suite should probably change that
    if [[ $(hostname) == *"-storage" ]]; then
        IP=$(ip -4 addr show eth0 | grep -oP "(?<=inet ).*(?=/)")
    else
        IP=$(ip -4 addr show eth1 | grep -oP "(?<=inet ).*(?=/)")
    fi
    pvcreate --zero n /dev/${ISCSI_DEV}
    vgcreate --zero n vg1_storage /dev/${ISCSI_DEV}
    targetcli /iscsi create iqn.2014-07.org.ovirt:storage
    targetcli /iscsi/iqn.2014-07.org.ovirt:storage/tpg1/portals \
        delete 0.0.0.0 3260
    targetcli /iscsi/iqn.2014-07.org.ovirt:storage/tpg1/portals \
        create ip_address=$IP ip_port=3260


    create_lun () {
       local ID=$1
        lvcreate --zero n -L20G -n lun${ID}_bdev vg1_storage
        targetcli \
            /backstores/block \
            create name=lun${ID}_bdev dev=/dev/vg1_storage/lun${ID}_bdev
        targetcli \
            /backstores/block/lun${ID}_bdev \
            set attribute emulate_tpu=1
        targetcli \
            /iscsi/iqn.2014-07.org.ovirt:storage/tpg1/luns/ \
            create /backstores/block/lun${ID}_bdev
    }


    for I in $(seq $NUM_LUNS);
    do
        create_lun $(($I - 1));
    done;

    targetcli /iscsi/iqn.2014-07.org.ovirt:storage/tpg1 \
        set auth userid=username password=password
    targetcli /iscsi/iqn.2014-07.org.ovirt:storage/tpg1 \
        set attribute demo_mode_write_protect=0 generate_node_acls=1 cache_dynamic_acls=1 default_cmdsn_depth=64
    targetcli saveconfig

    systemctl enable --now target
    sed -i 's/#node.session.auth.authmethod = CHAP/node.session.auth.authmethod = CHAP/g' /etc/iscsi/iscsid.conf
    sed -i 's/#node.session.auth.username = username/node.session.auth.username = username/g' /etc/iscsi/iscsid.conf
    sed -i 's/#node.session.auth.password = password/node.session.auth.password = password/g' /etc/iscsi/iscsid.conf
    sed -i 's/node.conn\[0\].timeo.noop_out_timeout = 5/node.conn\[0\].timeo.noop_out_timeout = 30/g' /etc/iscsi/iscsid.conf

    iscsiadm -m discovery -t sendtargets -p $IP
    iscsiadm -m node -L all
    rescan-scsi-bus.sh
    ls /dev/disk/by-id/scsi-36* | cut -d - -f 3 | sort > /root/multipath.txt
    iscsiadm -m node -U all
    iscsiadm -m node -o delete
    systemctl disable --now iscsi.service
}

install_firewalld() {
    if [[ "$DIST" == "el7" ]]; then
        if  ! rpm -q firewalld > /dev/null; then
            {
                yum install -y firewalld && \
                {
                systemctl enable firewalld
                systemctl start firewalld
                firewall-cmd --permanent --zone=public --add-interface=eth0
                systemctl restart firewalld;
                }
            }
        else
            systemctl enable firewalld
            systemctl start firewalld
        fi
    fi
}

configure_firewalld() {
    if rpm -q firewalld > /dev/null; then
        if ! systemctl status firewalld > /dev/null; then
            systemctl start firewalld
        fi

        firewall-cmd --permanent --add-service=iscsi-target
        firewall-cmd --permanent --add-service=ldap
        firewall-cmd --permanent --add-service=nfs
        firewall-cmd --permanent --add-service=ntp
        firewall-cmd --reload
    fi
}

disable_firewalld() {
    if rpm -q firewalld > /dev/null; then
            systemctl disable --now firewalld || true
    fi
}

setup_services() {
    install_firewalld
    configure_firewalld

    # Configure rpc.mountd to use port 892
    sed -i '/\[mountd\]/aport=892' /etc/nfs.conf

    # Configure rpc.statd to use port 662
    sed -i '/\[statd\]/aport=662' /etc/nfs.conf

    # Configure lockd to use ports 32803/tcp and 32769/udp
    sed -i '/\[lockd\]/aport=32803\nudp-port=32769' /etc/nfs.conf

    systemctl restart rpcbind.service
    systemctl enable --now rpcbind.service
    systemctl enable --now  nfs-server.service
    systemctl start nfs-idmapd.service
}

install_deps_389ds() {
    if  ! rpm -q 389-ds-base 389-ds-base-legacy-tools > /dev/null; then
        dnf module -y enable 389-ds
        yum install --nogpgcheck -y 389-ds-base 389-ds-base-legacy-tools
    fi
}

setup_389ds() {
    DOMAIN=lago.local
    PASSWORD=12345678
    HOSTNAME=$(hostname | sed s/_/-/g)."$DOMAIN"
    NIC=$(ip route |awk '$1=="default" {print $5; exit}')
    ADDR=$(\
      /sbin/ip -4 -o addr show dev $NIC \
      | awk '{split($4,a,"."); print a[1] "." a[2] "." a[3] "." a[4]}'\
      | awk -F/ '{print $1}'\
    )
    cat >> answer_file.inf <<EOC
[General]
FullMachineName= @HOSTNAME@
SuiteSpotUserID= root
SuiteSpotGroup= root
ConfigDirectoryLdapURL= ldap://@HOSTNAME@:389/o=NetscapeRoot
ConfigDirectoryAdminID= admin
ConfigDirectoryAdminPwd= @PASSWORD@
AdminDomain= @DOMAIN@

[slapd]
ServerIdentifier= lago
ServerPort= 389
Suffix= dc=lago, dc=local
RootDN= cn=Directory Manager
RootDNPwd= @PASSWORD@

[admin]
ServerAdminID= admin
ServerAdminPwd= @PASSWORD@
SysUser= dirsrv
EOC

    sed -i 's/@HOSTNAME@/'"$HOSTNAME"'/g' answer_file.inf
    sed -i 's/@PASSWORD@/'"$PASSWORD"'/g' answer_file.inf
    sed -i 's/@DOMAIN@/'"$DOMAIN"'/g' answer_file.inf

    cat >> add_user.ldif <<EOC
dn: uid=user1,ou=People,dc=lago,dc=local
uid: user1
givenName: user1
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetorgperson
objectclass: inetuser
sn: user1
cn: user1 user1
userPassword: {SSHA}1e/GY7pCEhoL5yMR8HvjI7+3me6PQtxZ
memberOf: cn=mygroup,ou=Groups,dc=lago,dc=local
# Password is 123456
EOC
    cat >> add_group.ldif <<EOC
dn: cn=mygroup,ou=Groups,dc=lago,dc=local
changetype: add
objectClass: top
objectClass: posixGroup
objectClass: groupOfUniqueNames
gidNumber: 12345
cn: mygroup
uniqueMember: uid=user1,ou=People,dc=lago,dc=local
EOC
    /usr/sbin/setup-ds.pl -dd --silent --file=answer_file.inf \
     --logfile=/var/log/setup-ds.log

    ldapadd -x -H ldap://localhost -D 'cn=Directory Manager' -w $PASSWORD -f add_user.ldif
    ldapadd -x -H ldap://localhost -D 'cn=Directory Manager' -w $PASSWORD -f add_group.ldif
    systemctl stop dirsrv@lago
    sed -i 's/^nsslapd-cachememsize:.*/nsslapd-cachememsize: 512000/' /etc/dirsrv/slapd-lago/dse.ldif
    sed -i 's/^nsslapd-dncachememsize:.*/nsslapd-dncachememsize: 512000/' /etc/dirsrv/slapd-lago/dse.ldif
    sed -i 's/^nsslapd-dbcachesize:.*/nsslapd-dbcachesize: 512000/' /etc/dirsrv/slapd-lago/dse.ldif
    sed -i 's/^nsslapd-cache-autosize:.*/nsslapd-cache-autosize: 0/' /etc/dirsrv/slapd-lago/dse.ldif
}

setup_lvm_filter() {
    cat > /etc/lvm/lvmlocal.conf <<EOC

devices {
        # Either sdb or sdc devices can include VG, from which we slice out logical volumes
        global_filter = [ "a|/dev/sdb|", "a|/dev/sdc|", "r|.*|" ]
}

EOC
}

setup_ipv6_and_dns() {
    HOST_COUNT=2
    DOMAIN=$(dnsdomainname)
    LOCAL_HOSTNAME_PREFIX=$(hostname | awk '{gsub(/[^-]*$/,""); print}')
    IPV6NET="fd8f:1391:3a82:"
    NIC="eth1"
    SUBNET=${IPV6_SUBNET}
    HOST_LOCAL_PREFIX=10
    ADDR_PREFIX=64
    HOST_NAME="host"
    STORAGE_NAME="storage"
    STORAGE_IP_SUFFIX=200
    HE_NAME="ostengine"
    HE_SUFFIX=250

    nmcli con modify ${NIC} ipv6.addresses ${IPV6NET}${SUBNET}::${STORAGE_IP_SUFFIX}/${ADDR_PREFIX} \
    ipv6.gateway ${IPV6NET}${SUBNET}::1 ipv6.method manual
    nmcli con modify ${NIC} ipv4.method disabled
    nmcli con up ${NIC}

    for ((i=0;i<${HOST_COUNT};i++)); do
        echo  "${IPV6NET}${SUBNET}::${HOST_LOCAL_PREFIX}${i} ${LOCAL_HOSTNAME_PREFIX}${HOST_NAME}-${i}.${DOMAIN} ${LOCAL_HOSTNAME_PREFIX}${HOST_NAME}-${i}" >> /etc/hosts
    done

    echo "${IPV6NET}${SUBNET}::${STORAGE_IP_SUFFIX} ${LOCAL_HOSTNAME_PREFIX}${STORAGE_NAME}.${DOMAIN} ${LOCAL_HOSTNAME_PREFIX}${STORAGE_NAME}" >> /etc/hosts
    echo "${IPV6NET}${SUBNET}::${HE_SUFFIX} ${LOCAL_HOSTNAME_PREFIX}${HE_NAME}.${DOMAIN} ${LOCAL_HOSTNAME_PREFIX}${HE_NAME}" >> /etc/hosts
}

main() {
    if [[ $(hostname) == *"ipv6"* ]]; then
        setup_ipv6_and_dns
    fi
    # Prepare storage
    install_deps
    setup_services
    setup_main_nfs
    setup_export
    setup_iso
    setup_second_nfs
    set_selinux_on_nfs
    activate_nfs
    setup_lvm_filter
    setup_iscsi

    # Prepare 389ds
    install_deps_389ds
    setup_389ds

    fstrim -va
}


main

