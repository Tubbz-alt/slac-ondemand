FROM centos:centos7

# setup slurm
# shoudl probably user a docker builder AS or something rather than doing again here... perhaps from the slurm image?
ARG MUNGEUSER=891
ARG SLURMUSER=16924
ARG SLURMGROUP=1034

RUN groupadd -g $MUNGEUSER munge \
    && useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGEUSER -g munge  -s /sbin/nologin munge \
    && groupadd -g $SLURMGROUP slurm \
    && useradd  -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSER -g slurm  -s /bin/bash slurm

# httpd24-mod_ssl httpd24-mod_ldap \
RUN set -xe \
    && yum makecache fast \
    && yum -y update \
    && yum -y install epel-release centos-release-scl wget \
    && wget https://turbovnc.org/pmwiki/uploads/Downloads/TurboVNC.repo -O /etc/yum.repos.d/TurboVNC.repo \
    && yum -y update \
    && yum install -y \
        munge \
        openssh-server openssh-clients \
        sudo \
        python-setuptools sssd nss-pam-ldapd \
    && yum -y install turbovnc \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && easy_install supervisor

#
#    && mkdir /var/spool/slurmd /var/run/slurmd /var/lib/slurmd /var/log/slurm \
#    && chown slurm:root /var/spool/slurmd /var/run/slurmd /var/lib/slurmd /var/log/slurm \
#    && /sbin/create-munge-key \
#

# setup sssd
#COPY sssd/nsswitch.conf sssd/nslcd.conf /etc/
COPY sssd/nsswitch.conf /etc/
COPY sssd/sssd.conf /etc/sssd/sssd.conf
RUN chmod 600 /etc/sssd/sssd.conf

# setup tini
ADD https://github.com/krallin/tini/releases/download/v0.18.0/tini /usr/sbin/tini
RUN chmod +x /usr/sbin/tini

# envs
#ENV MUNGE_ARGS=''
ENV PATH=/opt/TurboVNC/bin/:${PATH}

# oidc
RUN yum install -y https://yum.osc.edu/ondemand/latest/ondemand-release-web-1.8-1.noarch.rpm \
    && yum install --nogpgcheck -y ondemand httpd24-mod_auth_openidc \
    && ln -sf /etc/ood/config/portal/ood_portal.yml /etc/ood/config/ood_portal.yml \
    && mkdir -p /etc/ood/config/portal \
       /etc/ood/config/clusters.d \
       /etc/ood/config/htpasswd/ \
       /etc/ood/config/apps/shell \
       /etc/ood/config/apps/bc_desktop 

# copy over latest documentaiton
RUN git clone https://github.com/slaclab/sdf-docs.git /var/www/ood/public/doc/

# copy over exe's
COPY docker-entrypoint.sh supervisord-eventlistener.sh ondemand.sh supervisord.conf /

# slrm paths
RUN mkdir /var/spool/slurmd /var/run/slurmd /var/lib/slurmd /var/log/slurm \
    && chown slurm:root /var/spool/slurmd /var/run/slurmd /var/lib/slurmd /var/log/slurm 
ENV PATH=/opt/slurm/bin:${PATH}

# start
ENTRYPOINT ["/usr/sbin/tini", "--", "/docker-entrypoint.sh"]
