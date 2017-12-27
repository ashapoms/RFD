#!/bin/sh

# This script can be found on https://github.com/Azure/azure-quickstart-templates/blob/master/torque-cluster/azuredeploy.sh
# This script is part of azure deploy ARM template
# This script assumes the Linux distribution to be Ubuntu (or at least have apt-get support)
# This script will install Torque on a Linux cluster deployed on a set of Azure VMs

# Basic info
date > /tmp/azuredeploy.log.$$ 2>&1
whoami >> /tmp/azuredeploy.log.$$ 2>&1
echo $@ >> /tmp/azuredeploy.log.$$ 2>&1

# Usage
if [ "$#" -ne 9 ]; then
  echo "Usage: $0 MASTER_NAME MASTER_IP WORKER_NAME WORKER_IP_BASE WORKER_IP_START NUM_OF_VM ADMIN_USERNAME ADMIN_PASSWORD TEMPLATE_BASE" >> /tmp/azuredeploy.log.$$
  exit 1
fi

# Preparation steps - hosts and ssh
###################################

# Parameters
MASTER_NAME=$1
MASTER_IP=$2
WORKER_NAME=$3
WORKER_IP_BASE=$4
WORKER_IP_START=$5
NUM_OF_VM=$6
ADMIN_USERNAME=$7
ADMIN_PASSWORD=$8
TEMPLATE_BASE=$9
declare -r share_nfs="/shared"
declare -r share_azure="/mnt/shared"
declare -r share_azure_logs="${share_azure}/logs"
declare -r impi_folder="${share_nfs}/impi"
#declare -r impi_share="${impi_folder/l_mpi_2018.1.163"

declare -r impi_ver="4.1.3.049"
declare -Ar file_list="([efplugins]="efplugins.tar.gz" [openlava]="openlava-2.2-2.x86_64.rpm" [tnav-data1]="SpeedTestModel.zip" [tnav-data2]="SpeedTestLarge.zip" [tnav-data3]="SpeedTestLarge_short.zip" [enginframe]="enginframe-2015.0-r36730.jar" [dante]="dante-1.4.1-1.el6.x86_64.rpm" [tnav-ini]="queue_viewers.ini" [mpirun]="impi-mpirun" [tnav-license]="license.dat" [tnav-conf]="tNavigator.conf" [tnav-license-status]="tNavigator-license_status-Linux-64.zip" [jdk]="jdk-8u60-linux-x64.tar.gz" [tnav-con]="tNavigator-con-Linux-64.zip" [tnav-con-mpi]="tNavigator-con-mpi-Linux-64.zip" [dcv]="nice-dcv-2014.0-16231.run" [elim]="elim" [impi]="impi-4.1.3.049.tar.gz" [get-pip]="get-pip.py" [tnav-logo]="rfdlogo.png" [tnav-dispatcher]="tNavigator-dispatcher-install-Linux-64.zip" [dante-server]="dante-server-1.4.1-1.el6.x86_64.rpm" [tnav-guiapp]="tNavigator-Linux-64.zip" )"
declare -r tnav_dispatcher_folder="/opt/RFD"

# Update master node
echo $MASTER_IP $MASTER_NAME >> /etc/hosts
echo $MASTER_IP $MASTER_NAME > /tmp/hosts.$$

# Need to disable requiretty in sudoers, I'm root so I can do this.
sed -i "s/Defaults\s\{1,\}requiretty/Defaults \!requiretty/g" /etc/sudoers

# Update ssh config file to ignore unknow host
# Note all settings are for azureuser, NOT root
sudo -u $ADMIN_USERNAME sh -c "mkdir /home/$ADMIN_USERNAME/.ssh/;echo Host worker\* > /home/$ADMIN_USERNAME/.ssh/config; echo StrictHostKeyChecking no >> /home/$ADMIN_USERNAME/.ssh/config; echo UserKnownHostsFile=/dev/null >> /home/$ADMIN_USERNAME/.ssh/config"

# Generate a set of sshkey under /honme/azureuser/.ssh if there is not one yet
if ! [ -f /home/$ADMIN_USERNAME/.ssh/id_rsa ]; then
    sudo -u $ADMIN_USERNAME sh -c "ssh-keygen -f /home/$ADMIN_USERNAME/.ssh/id_rsa -t rsa -N ''"
fi

# Install sshpass to automate ssh-copy-id action
sudo yum install -y epel-release
sudo yum install -y sshpass

# Loop through all worker nodes, update hosts file and copy ssh public key to it
# The script make the assumption that the node is called %WORKER+<index> and have
# static IP in sequence order
i=0
while [ $i -lt $NUM_OF_VM ]
do
   workerip=`expr $i + $WORKER_IP_START`
   echo 'I update host - '$WORKER_NAME$i >> /tmp/azuredeploy.log.$$ 2>&1
   echo $WORKER_IP_BASE$workerip $WORKER_NAME$i >> /etc/hosts
   echo $WORKER_IP_BASE$workerip $WORKER_NAME$i >> /tmp/hosts.$$
   sudo -u $ADMIN_USERNAME sh -c "sshpass -p '$ADMIN_PASSWORD' ssh-copy-id $WORKER_NAME$i"
   i=`expr $i + 1`
done
# Install Azure Files packages and mount+configure it
sudo -S yum -y install samba-client samba-common cifs-utils nfs-utils libnfsidmap

disable_selinux_policy(){
  sed -i "s/^SELINUX=.*$/SELINUX=disabled/g" /etc/selinux/config
}

disable_selinux_policy

configure_nfs_server(){
   declare sharenfs="/shared"
   systemctl start rpcbind
   systemctl start nfs-server
   systemctl start rpc-statd
   systemctl start nfs-idmapd
   mkdir ${sharenfs}
   chmod 777 ${sharenfs}
   cat > '/etc/exports' <<EOF
   /home 10.0.0.0/16(rw,no_root_squash,sync)
   ${sharenfs} 10.0.0.0/16(rw,no_root_squash,sync)
EOF
    exportfs -rav
}

configure_nfs_server >> /tmp/environment.log

connect_to_azure_files_share_and_copy_env(){
  declare -r shareazure_path="//rfdstorage.file.core.windows.net/rfd"
  declare -r share_pass="7Q+/+S8t/P2NNkIxp3zT15E4kZRdufcDldjCzpRB+Z2QPjgyThbPedHMX8++/mhOdc8nkfJ8Zt/3wVzzT72a1A=="
  declare -r share_username="rfdstorage"
  declare share_include_cmd="${shareazure_path} ${share_azure} -o vers=3.0,username=${share_username},password=${share_pass},dir_mode=0777,file_mode=0777,serverino"
  mkdir -p ${share_azure}
  mount -t cifs ${share_include_cmd}
  cp -r ${share_azure}/* ${share_nfs}

  echo ${share_include_cmd} >> /etc/fstab 
}

echo "=======================" >> /tmp/environment.log
echo "Azure Files is being configured" >> /tmp/environment.log
echo "=======================" >> /tmp/environment.log
connect_to_azure_files_share_and_copy_env >> /tmp/environment.log

openldap_master_install(){
  yum install -y openldap compat-openldap openldap-clients openldap-servers openldap-servers-sql openldap-devel libusb
 
  declare -r share_ldap_schemas="${share_nfs}/scripts"
  slappasswd -h {MD5} -s "$ADMIN_PASSWORD"
  ldapadd -Y EXTERNAL -H ldapi:/// -f ${share_ldap_schemas}/adminpassword.ldif
  ldapadd -x -D cn=admin,cn=config -W -f /etc/openldap/schema/cosine.ldif
  ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif && sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
  ldapadd -Y EXTERNAL -H ldapi:/// -f ${share_ldap_schemas}/domain.ldif
  ldapadd -x -D cn=Manager,dc=rfd,dc=com -W -f ${share_ldap_schemas}/basedomain.ldif
  systemctl stop slapd
  systemctl start slapd
 sudo ldapadd -x -W -D "cn=Manager,dc=rfd,dc=com" -f ${share_ldap_schemas}/users.ldif
}
####Install and setting OpenLDAP up
#sudo yum remove openldap-servers && sudo  rm -rf /etc/openldap/
#sudo yum install -y openldap-servers
echo "=======================" >> ${share_azure_logs}/environment.log
echo "OpenLDAP is being configured" >> ${share_azure_logs}/environment.log
echo "=======================" >> ${share_azure_logs}/environment.log
#openldap_master_install >> ${share_azure_logs}/environment.log

# Include MPI
###########################
configure_mpi(){
    #/shared/Intel\impi-4.1.3.049.tar
    #sh ${impi_share}/install.sh --silent ${impi_share}/silent.cfg  
    mkdir -p "${impi_folder}" && tar -C $_ -zxf "/shared/pkgs/Intel/impi-4.1.3.049.tar.gz"    
    source "${impi_folder}/${impi_ver}/bin64/mpivars.sh"
    ln -sf "${impi_folder}/${impi_ver}/bin64/mpivars.sh" '/etc/profile.d/mpivars.sh'
}

echo "=======================" >> ${share_azure_logs}/environment.log
echo "MPI is being configured" >> ${share_azure_logs}/environment.log
echo "=======================" >> ${share_azure_logs}/environment.log
configure_mpi >> ${share_azure_logs}/environment.log

####################

# Install Torque 
################
torque_setup(){
        sudo -S yum install -y libtool openssl-devel libxml2-devel boost-devel gcc gcc-c++

        # Download the source package
        cp "${share_nfs}/pkgs/torque.tar.gz" /tmp 
        cd /tmp >> /tmp/azuredeploy.log.$$ 2>&1
        #wget http://www.adaptivecomputing.com/index.php?wpfb_dl=2936 -O torque.tar.gz >> /tmp/azuredeploy.log.$$ 2>&1
        tar xzvf torque.tar.gz >> /tmp/azuredeploy.log.$$ 2>&1
        cd torque-5.1.1* >> /tmp/azuredeploy.log.$$ 2>&1

        # Build
        ./configure >> /tmp/azuredeploy.log.$$ 2>&1
        make >> /tmp/azuredeploy.log.$$ 2>&1
        make packages >> /tmp/azuredeploy.log.$$ 2>&1
        sudo make install >> /tmp/azuredeploy.log.$$ 2>&1

        export PATH=/usr/local/bin/:/usr/local/sbin/:$PATH

        # Create and start trqauthd
        sudo cp contrib/init.d/trqauthd /etc/init.d/
        sudo chkconfig --add trqauthd
        sudo sh -c "echo /usr/local/lib > /etc/ld.so.conf.d/torque.conf"
        sudo ldconfig
        sudo service trqauthd start

        # Update config
        sudo sh -c "echo $MASTER_NAME > /var/spool/torque/server_name"

        sudo env "PATH=$PATH" sh -c "echo 'y' | ./torque.setup root" >> /tmp/azuredeploy.log.$$ 2>&1

        #sudo sh -c "echo $MASTER_NAME > /var/spool/torque/server_priv/nodes" >> /tmp/azuredeploy.log.$$ 2>&1

        # Start pbs_server
        sudo cp contrib/init.d/pbs_server /etc/init.d >> /tmp/azuredeploy.log.$$ 2>&1
        sudo chkconfig --add pbs_server >> /tmp/azuredeploy.log.$$ 2>&1
        sudo service pbs_server restart >> /tmp/azuredeploy.log.$$ 2>&1

        # Start pbs_mom
#        sudo cp contrib/init.d/pbs_mom /etc/init.d >> /tmp/azuredeploy.log.$$ 2>&1
#        sudo chkconfig --add pbs_mom >> /tmp/azuredeploy.log.$$ 2>&1
#        sudo service pbs_mom start >> /tmp/azuredeploy.log.$$ 2>&1

        # Start pbs_sched
        sudo env "PATH=$PATH" pbs_sched >> /tmp/azuredeploy.log.$$ 2>&1

}
# Prep packages
echo "=======================" >> ${share_azure_logs}/environment.log
echo "Torque is being configured" >> ${share_azure_logs}/environment.log
echo "=======================" >> ${share_azure_logs}/environment.log
torque_setup >> ${share_azure_logs}/environment.log


# Install sshpass to automate ssh-copy-id action and copy ssh
ssh_pass_copy(){
    yum install -y epel-release
    yum install -y sshpass
    #ssh to trust master
    ssh-keygen -f /home/$1/.ssh/id_rsa -t rsa -N ""
    sshpass -p $2 ssh-copy-id $1@$3 
    #authconfig --enableldap --enableldapauth --ldapserver=ldap://$3:389/ --ldapbasedn='dc=rfd,dc=com' --disablefingerprint --kickstart --update >> /tmp/openldap.txt
}



configure_tNavigator() {
 declare -r shareddata="${share_nfs}/data"
  declare -r tnav_default_queue='batch'
  declare -r rfdlogo='rfdlogo.png'
  declare -ir tnav_dispatcher_port="5557"
  impi_path=${impi_folder}${impi_ver}
  
  declare -r tnav_desktop='/etc/skel/Desktop/tNavigator.desktop'
      mkdir -p \
          "${tnav_dispatcher_folder}/bin" \
          "${shareddata}" \
          '/etc/skel/Desktop' \
          '/etc/skel/.config/RFDynamics/tNavigator'\

      declare -ra tnav_files=(
          "${file_list[tnav-con]}"
          "${file_list[tnav-con-mpi]}"
          "${file_list[tnav-dispatcher]}"
          "${file_list[tnav-guiapp]}"
          "${file_list[tnav-data1]}"
          "${file_list[tnav-data2]}"
          "${file_list[tnav-data3]}"
          "${file_list[tnav-license-status]}"
      )

      local -- file=''
      for file in "${tnav_files[@]}"; do
          unzip -d "${tnav_dispatcher_folder}" "${share_nfs}/pkgs/rfdyn/${file}" 
      done

    unzip -d "${share_nfs}" 'tNavigator-con-Linux-64.zip'
    unzip -d "${share_nfs}" 'tNavigator-con-mpi-Linux-64.zip'
    unzip -d "${share_nfs}" 'tNavigator-license_status-Linux-64.zip'


      #echo "${licenseDat}" > "${sharedtnav}/tnav.license.dat"
      cp ${share_nfs}/tnav_license.dat $tnav_dispatcher_folder
      #cp "${rfdlogo}" "${sharedtnav}/rfdlogo.png"


      mv "${tnav_dispatcher_folder}/$(basename "${file_list[tnav-data1]}" '.zip')" \
          "${shareddata}"
      chmod -R 1777 "${shareddata}"

      #mv "${share_pkgs_folder}/${file_list[tnav-license]}" "${sharedtnav}/tnav.license.dat"

      #mv "${share_pkgs_folder}/${file_list[tnav-logo]}" "${sharedtnav}"

      "${tnav_dispatcher_folder}/tNavigator-dispatcher-install-Linux-64/install.sh" \
          --service-name=tNavigator-dispatcher \
          --auth-method=login_passwd
      echo "alias runtnav='/opt/RFD/dispatcher/scripts/runtnav.sh'" | sudo tee -a /home/$ADMIN_USERNAME/.bashrc
}

sed -e 's/^export PATH.*$/#&/g' \        
                -e 's/^export runtnav__queue_manager=.*$/export runtnav__queue_manager="torque"/g' \
                -e 's/^export runtnav__intel_mpi_dir=.*$/export runtnav__intel_mpi_dir="'"${impi_path////\/}"'\/intel64"/g' \
                -e 's/^export runtnav__add_mpirun_params=.*$/export runtnav__add_mpirun_params="-launcher ssh -env I_MPI_DEBUG 6"/g' \
                -e 's/^export runtnav__tNavigator_dir=.*$/export runtnav__tNavigator_dir="'"${tnav_dispatcher_folder////\/}"'"/g' \
                -e 's/^export runtnav__license_server_ip=.*$/#&/g' \
                -e 's/^export runtnav__license_server_url=.*$/export runtnav__license_server_url="lic-set-file:\/\/\/opt\/RFD\/tnav_license.dat"/g' \
                -e 's/^export runtnav__default_thread_count=.*$/export runtnav__default_thread_count="1"/g' \
                -e 's/^export runtnav__default_queue=.*$/export runtnav__default_queue="'"${tnav_default_queue////\/}"'"/g' \
                -e 's/^export runtnav_remote_gui__dispatcher_ip=.*$/export runtnav_remote_gui__dispatcher_ip="10.0.0.254"/g' \
                -e 's/^export runtnav_remote_gui__dispatcher_port=.*$/export runtnav_remote_gui__dispatcher_port="'"${tnav_dispatcher_port////\/}"'"/g' \
                 "${tnav_dispatcher_folder}/dispatcher/scripts/runtnav_config.sh.default" > "${tnav_dispatcher_folder}/dispatcher/scripts/runtnav_config.sh"

${tnav_dispatcher_folder}/dispatcher/dispatcher.sh start 
configure_tNavigator >> ${share_azure_logs}/environment.log

configure_nfs_client(){
   declare -r share_azure="/shared"
   MASTER_NAME="master"
   systemctl enable rpcbind
   systemctl start rpcbind  
   echo "master:/home /home nfs hard,intr,noatime,vers=4,_netdev 0 0" | sudo tee -a /etc/fstab
   echo "master:${share_azure} ${share_azure} nfs hard,intr,noatime,vers=4,_netdev 0 0" | sudo tee -a /etc/fstab
  
   mkdir ${share_azure}
   mount $MASTER_NAME:$share_azure $share_azure 
   mount $MASTER_NAME:/home /home
 }


echo "=======================" >> ${share_azure_logs}/environment.log
echo "Nodes are starting to configure" >> ${share_azure_logs}/environment.log
echo "=======================" >> ${share_azure_logs}/environment.log
# Push packages to compute nodes
i=0
while [ $i -lt $NUM_OF_VM ]
do
  worker=$WORKER_NAME$i
#azure files and share
echo "=======================" >> ${share_azure_logs}/environment.log
echo "Node === " $worker " === is being configured" >> ${share_azure_logs}/environment.log
echo "=======================" >> ${share_azure_logs}/environment.log
sudo -u $ADMIN_USERNAME ssh -tt $worker "echo '$ADMIN_PASSWORD' | sudo -kS sh -c 'yum install -y libusb samba-client samba-common cifs-utils openldap compat-openldap openldap-clients openldap-servers openldap-servers-sql nfs-utils libnfsidmap openldap-devel'"

typeset -f | sudo -u $ADMIN_USERNAME ssh -tt $worker "echo '$ADMIN_PASSWORD'| sudo -kS sh -c '$(cat);disable_selinux_policy;ssh_pass_copy ${ADMIN_USERNAME} ${ADMIN_PASSWORD} ${MASTER_NAME};configure_nfs_client'" >> ${share_azure_logs}/environment.log

#install torque
  sudo -u $ADMIN_USERNAME scp /tmp/hosts.$$ $ADMIN_USERNAME@$worker:/tmp/hosts >> /tmp/azuredeploy.log.$$ 2>&1
  sudo -u $ADMIN_USERNAME scp torque-package-mom-linux-x86_64.sh $ADMIN_USERNAME@$worker:/tmp/. >> /tmp/azuredeploy.log.$$ 2>&1
  sudo -u $ADMIN_USERNAME ssh -tt $worker "echo '$ADMIN_PASSWORD' | sudo -kS sh -c 'cat /tmp/hosts>>/etc/hosts'" 
  sudo -u $ADMIN_USERNAME ssh -tt $worker "echo '$ADMIN_PASSWORD' | sudo -kS /tmp/torque-package-mom-linux-x86_64.sh --install"
  sudo -u $ADMIN_USERNAME ssh -tt $worker "echo '$ADMIN_PASSWORD' | sudo -kS /usr/local/sbin/pbs_mom"
  echo $worker >> /var/spool/torque/server_priv/nodes
  i=`expr $i + 1`

echo "=======================" >> ${share_azure_logs}/environment.log
echo "Node === " $worker " === is healthy" >> ${share_azure_logs}/environment.log
echo "=======================" >> ${share_azure_logs}/environment.log

done

# Restart pbs_server
sudo service pbs_server restart >> /tmp/azuredeploy.log.$$ 2>&1

exit 0
