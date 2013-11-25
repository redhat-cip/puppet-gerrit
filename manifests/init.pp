# = Class: gerrit
#
# This is the main gerrit class
#
#
# == Parameters
#
# Standard class parameters
# Define the general class behaviour and customizations
#
# [*gerrit_version*]
#   Version of gerrit to install
#
# [*gerrit_home*]
#   Home-Dir of gerrit user
#
# [*gerrit_site_name*]
#   Name of gerrit review site directory
#
# Gerrit config variables:
#
# [*canonical_web_url*]
#   Canonical URL of the Gerrit review site, used on generated links
#
# [*sshd_listen_address*]
#   "<ip>:<port>" for the Gerrit SSH server to bind to
#
# [*httpd_listen_url*]
#   "<schema>://<ip>:<port>/<context>" for the Gerrit webapp to bind to
#
# == Author
#   Robert Einsle <robert@einsle.de>
#   François Charlier <francois.charlier@enovance.com>
#
class gerrit (
  $gerrit_version       = '2.7',
  $gerrit_home          = '/opt/gerrit',
  $gerrit_site_name     = 'review_site',
  # $gerrit_database_type = $gerrit_database_type,
  $canonical_web_url    = "http://${::fqdn}:8081",
  $sshd_listen_address  = '*:29418',
  $httpd_listen_url     = 'http://*:8081/',
  $download_mirror      = 'http://gerrit.googlecode.com/files',
  $email_format         = '{0}@example.com'
) inherits gerrit::params {

  $gerrit_war_file = "${gerrit_home}/gerrit-${gerrit_version}.war"

  # Install required packages
  ensure_packages(['wget', 'git', $gerrit_java])

  # Crate Group for gerrit
  group { $gerrit_group:
    ensure     => "present",
  }

  # Create User for gerrit-home
  user { $gerrit_user:
    ensure     => present,
    comment    => 'User for gerrit instance',
    home       => $gerrit_home,
    shell      => '/bin/false',
    gid        => $gerrit_group,
    managehome => true,
  }

  # Correct gerrit_home uid & gid
  file { $gerrit_home:
    ensure     => directory,
    owner      => $gerrit_user,
    group      => $gerrit_group,
  }

  if (versioncmp($gerrit_version, '2.5') < 0) or
     (versioncmp($gerrit_version, '2.5.2') > 0){
    $warfile = "gerrit-${gerrit_version}.war"
  } else {
    $warfile = "gerrit-full-${gerrit_version}.war"
  }

  # Funktion für Download eines Files per URL
  if $download_mirror =~ /^http/ {
    exec { 'download_gerrit':
      command => "wget -q '${download_mirror}/${warfile}' -O ${gerrit_war_file}",
      creates => "${gerrit_war_file}",
      require => [
        Package['wget'],
        User[$gerrit_user],
        File[$gerrit_home]
      ],
      before => File['gerrit_war']
    }
  }

  # Changes user / group of gerrit war
  file { 'gerrit_war':
    path    => $gerrit_war_file,
    owner   => $gerrit_user,
    group   => $gerrit_group,
    source  => $download_mirror ? {
      /^http/ => undef,
      default => "${download_mirror}/${warfile}"
    },
  }

  $command = "java -jar ${gerrit_war_file} init -d $gerrit_home/${gerrit_site_name} --batch --no-auto-start"

  # Initialisation of gerrit site
  exec { 'init_gerrit':
      cwd       => $gerrit_home,
      user      => $gerrit_user,
      command   => $command,
      creates   => "${gerrit_home}/${gerrit_site_name}/bin/gerrit.sh",
      logoutput => on_failure,
      require   => [
        Package[$gerrit_java],
        File['gerrit_war'],
      ],
  } ->
  # some init script would be nice
  file {'/etc/default/gerritcodereview':
    ensure  => present,
    content => "GERRIT_SITE=${gerrit_home}/${gerrit_site_name}\n",
    owner   => $gerrit_user,
    group   => $gerrit_group,
    mode    => '0444',
  }->
  file {'/etc/init.d/gerrit':
    ensure => symlink,
    target => "${gerrit_home}/${gerrit_site_name}/bin/gerrit.sh",
  } ->
  # Make sure the init script starts on boot.
  file { ['/etc/rc0.d/K10gerrit',
          '/etc/rc1.d/K10gerrit',
          '/etc/rc2.d/S90gerrit',
          '/etc/rc3.d/S90gerrit',
          '/etc/rc4.d/S90gerrit',
          '/etc/rc5.d/S90gerrit',
          '/etc/rc6.d/K10gerrit']:
    ensure  => link,
    target  => '/etc/init.d/gerrit',
    require => File['/etc/init.d/gerrit'],
  }

  # Manage Gerrit's configuration file (augeas would be more suitable).
  file { "${gerrit_home}/${gerrit_site_name}/etc/gerrit.config":
    content => template('gerrit/gerrit.config'),
    owner   => $gerrit_user,
    group   => $gerrit_group,
    mode    => '0444',
    require => Exec['init_gerrit'],
    notify  => Service['gerrit']
  }

  service { 'gerrit':
    ensure    => running,
    hasstatus => false,
    pattern   => 'GerritCodeReview',
    require   => File['/etc/init.d/gerrit']
  }

}
